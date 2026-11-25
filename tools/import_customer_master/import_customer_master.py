#!/usr/bin/env python3
"""
tools/import_customer_master/import_customer_master.py

Script impor data pelanggan (customer_master & customer_map_points) dari file KMZ KCLP ke Supabase.
Mendukung upsert massal idempoten dan opsi pembersihan data lama agar database hanya memuat data dari file ini.

Penggunaan:
    python tools/import_customer_master/import_customer_master.py --kmz "path/ke/KCLP_Pipien_Malviana2_siap_impor.kmz"
    python tools/import_customer_master/import_customer_master.py --kmz "path/ke/file.kmz" --replace
"""

import os
import sys
import re
import json
import argparse
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
import urllib.request
import urllib.error


def load_dotenv():
    """Membaca file .env jika ada di root project."""
    env_file = Path(".env")
    if env_file.exists():
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    k, v = k.strip(), v.strip().strip('"').strip("'")
                    if k not in os.environ or "xyzabcdefg" in os.environ[k]:
                        os.environ[k] = v


def parse_kmz(kmz_path: Path):
    """Membaca dan mem-parsing seluruh Placemark dari file KMZ KCLP."""
    with zipfile.ZipFile(kmz_path, 'r') as z:
        kml_files = [n for n in z.namelist() if n.lower().endswith('.kml')]
        if not kml_files:
            raise ValueError(f"Tidak ada file .kml di dalam archive KMZ: {kmz_path}")
        kml_data = z.read(kml_files[0])

    root = ET.fromstring(kml_data)
    ns = {'kml': 'http://www.opengis.net/kml/2.2'}
    placemarks = root.findall('.//kml:Placemark', ns)
    if not placemarks:
        # Fallback tanpa namespace
        placemarks = root.findall('.//Placemark')

    records = []
    seen_cids = set()

    for p in placemarks:
        name_el = p.find('kml:name', ns) if 'kml' in ns else p.find('name')
        desc_el = p.find('kml:description', ns) if 'kml' in ns else p.find('description')
        coord_el = p.find('.//kml:coordinates', ns) if 'kml' in ns else p.find('.//coordinates')

        cid = name_el.text.strip() if name_el is not None and name_el.text else None
        desc = desc_el.text if desc_el is not None and desc_el.text else ''

        # Parsing deskripsi HTML tabel
        rows = dict(re.findall(r'<tr><td>(.*?)</td><td>(.*?)</td></tr>', desc, re.DOTALL))

        # Koordinat
        lon, lat = None, None
        if coord_el is not None and coord_el.text:
            parts = coord_el.text.strip().split(',')
            if len(parts) >= 2:
                try:
                    lon = float(parts[0])
                    lat = float(parts[1])
                except ValueError:
                    pass

        if lat is None and 'Latitude' in rows:
            try:
                lat = float(rows['Latitude'])
            except ValueError:
                pass
        if lon is None and 'Longitude' in rows:
            try:
                lon = float(rows['Longitude'])
            except ValueError:
                pass

        final_cid = cid or rows.get('Customer ID')
        if not final_cid:
            continue
        final_cid = final_cid.strip()

        # Lewati duplikat di file yang sama
        if final_cid in seen_cids:
            continue
        seen_cids.add(final_cid)

        # Normalisasi sales_name, spv_name, tsc_name (spasi ganda -> 1, uppercase)
        def norm(s):
            return re.sub(r'\s+', ' ', (s or '').strip()).upper()

        records.append({
            'customer_id': final_cid,
            'city_code': (rows.get('City Code Homepass') or 'KCLP').strip().upper(),
            'install_date': (rows.get('Install Date') or None),
            'address': (rows.get('Homepass Address') or '').strip()[:500],
            'package_name': (rows.get('Product Name') or '').strip()[:200],
            'latitude': lat,
            'longitude': lon,
            'sales_name': norm(rows.get('Sales Name')),
            'spv_name': norm(rows.get('SPV Name')),
            'tsc_name': norm(rows.get('TSC Name')),
        })

    return records


def postgrest_request(url: str, service_key: str, method: str = 'GET', data=None, headers=None):
    """Eksekusi request HTTP ke Supabase PostgREST REST API."""
    body = json.dumps(data).encode('utf-8') if data is not None else None
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header('apikey', service_key)
    req.add_header('Authorization', f'Bearer {service_key}')
    req.add_header('Content-Type', 'application/json')
    if headers:
        for k, v in headers.items():
            req.add_header(k, v)

    with urllib.request.urlopen(req) as resp:
        content = resp.read().decode('utf-8')
        return resp.status, resp.headers, content


def main():
    load_dotenv()
    parser = argparse.ArgumentParser(description="Impor Data Pelanggan KCLP ke Supabase (customer_master)")
    parser.add_argument("--kmz", required=True, help="Path ke file KMZ (contoh: KCLP_Pipien_Malviana2_siap_impor.kmz)")
    parser.add_argument("--url", default=os.getenv("SUPABASE_URL"), help="Supabase project URL")
    parser.add_argument("--key", default=os.getenv("SUPABASE_SERVICE_KEY"), help="Supabase service role key")
    parser.add_argument("--replace", action="store_true", help="Bersihkan data lama di tabel sebelum impor")
    parser.add_argument("--batch-size", type=int, default=100, help="Jumlah baris per batch request (default 100)")

    args = parser.parse_args()

    supabase_url = args.url or "https://ycyzfrfvonxvxjpjrnoq.supabase.co"
    service_key = args.key

    if not service_key:
        print("[FATAL] SUPABASE_SERVICE_KEY belum diatur!", file=sys.stderr)
        sys.exit(1)

    kmz_path = Path(args.kmz)
    if not kmz_path.exists():
        print(f"[FATAL] File KMZ tidak ditemukan: {kmz_path}", file=sys.stderr)
        sys.exit(1)

    print(f"=== Membaca File KMZ: {kmz_path.name} ===")
    records = parse_kmz(kmz_path)
    print(f"Berhasil mem-parsing {len(records)} data pelanggan unik.")

    batch_id = kmz_path.stem[:64]
    for r in records:
        r['batch_id'] = batch_id

    # Opsi replace: Hapus data lama jika diminta
    if args.replace:
        print("\n[PERINGATAN] Opsi --replace aktif. Membersihkan data lama di customer_master...")
        del_url = f"{supabase_url.rstrip('/')}/rest/v1/customer_master?customer_id=neq.''"
        try:
            status, _, _ = postgrest_request(del_url, service_key, method='DELETE')
            print(f"  Data lama berhasil dibersihkan (Status HTTP {status}).")
        except Exception as e:
            print(f"  [ERROR] Gagal membersihkan data lama: {e}", file=sys.stderr)

    # Kirim data secara bertahap (batching)
    upsert_url = f"{supabase_url.rstrip('/')}/rest/v1/customer_master"
    headers = {
        'Prefer': 'resolution=merge-duplicates,return=minimal'
    }

    total = len(records)
    batch_size = args.batch_size
    success_count = 0

    print(f"\n=== Memulai Upsert Massal ke Supabase ({total} baris) ===")
    for i in range(0, total, batch_size):
        chunk = records[i:i + batch_size]
        try:
            status, _, _ = postgrest_request(upsert_url, service_key, method='POST', data=chunk, headers=headers)
            if status in (200, 201, 204):
                success_count += len(chunk)
                print(f"  -> Progress: {min(i + batch_size, total)}/{total} ({success_count} berhasil)")
            else:
                print(f"  [WARN] Batch {i}-{i+len(chunk)} respons status HTTP {status}")
        except urllib.error.HTTPError as e:
            err_body = e.read().decode('utf-8', errors='ignore')
            print(f"  [ERROR] Batch {i}-{i+len(chunk)} gagal: HTTP {e.code} - {err_body}", file=sys.stderr)
        except Exception as e:
            print(f"  [ERROR] Batch {i}-{i+len(chunk)} gagal: {e}", file=sys.stderr)

    print("\n================ RINGKASAN IMPOR ================")
    print(f"Total Data di File KMZ: {total}")
    print(f"Berhasil Disimpan      : {success_count}")
    print(f"Gagal / Terkendala     : {total - success_count}")
    print("Trigger database otomatis memperbarui customer_map_points.")
    print("==================================================")


if __name__ == '__main__':
    main()
