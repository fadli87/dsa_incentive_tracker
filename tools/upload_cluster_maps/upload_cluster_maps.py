#!/usr/bin/env python3
"""
tools/upload_cluster_maps/upload_cluster_maps.py

Script upload massal peta cluster dari folder lokal KAB.CILACAP (Google Drive)
ke Supabase Storage (bucket 'cluster-maps') dan tabel public.cluster_maps.

Penggunaan:
    python tools/upload_cluster_maps/upload_cluster_maps.py --dir "C:/path/ke/KAB.CILACAP"

Variabel Lingkungan (Environment Variables):
    SUPABASE_URL          - URL Supabase (contoh: https://xyz.supabase.co)
    SUPABASE_SERVICE_KEY  - Service Role Key Supabase (JANGAN gunakan anon key)
"""

import os
import sys
import re
import argparse
import mimetypes
from pathlib import Path
import urllib.request
import urllib.error
import json

CODE_PATTERN = re.compile(r'(XLCLP\d+)', re.IGNORECASE)
KELURAHAN_PATTERN = re.compile(r'KELURAHAN\s+([A-Z0-9\s]+?)(?:\s+RW|\s*-\s*|\s*,|$)', re.IGNORECASE)
RW_PATTERN = re.compile(r'RW\s*(\d+)', re.IGNORECASE)


def parse_cluster_folder_name(folder_name: str):
    """
    Ekstrak cluster_code, name, kelurahan, dan rw dari nama folder.
    Contoh: 'CLUSTER INTAN RESIDENCE, KELURAHAN GUMILIR RW 17 - XLCLP1947'
    -> code: XLCLP1947
    -> name: CLUSTER INTAN RESIDENCE, KELURAHAN GUMILIR RW 17
    -> kelurahan: GUMILIR
    -> rw: 17
    """
    match_code = CODE_PATTERN.search(folder_name)
    if not match_code:
        return None

    code = match_code.group(1).upper()

    # Bersihkan nama: buang bagian '- XLCLPxxxx' atau 'XLCLPxxxx'
    clean_name = re.sub(r'[-\s]*' + re.escape(code) + r'.*$', '', folder_name, flags=re.IGNORECASE).strip()
    clean_name = clean_name.rstrip(' -_,')
    if not clean_name:
        clean_name = folder_name

    kelurahan = None
    rw = None

    match_kel = KELURAHAN_PATTERN.search(clean_name)
    if match_kel:
        kelurahan = match_kel.group(1).strip().upper()

    match_rw = RW_PATTERN.search(clean_name)
    if match_rw:
        rw = match_rw.group(1).strip()

    return {
        'code': code,
        'name': clean_name,
        'kelurahan': kelurahan,
        'rw': rw
    }


def upload_to_storage(supabase_url: str, service_key: str, bucket: str, storage_path: str, file_path: Path) -> bool:
    """
    Upload / Overwrite file ke Supabase Storage via REST API.
    POST /storage/v1/object/{bucket}/{storage_path} dengan x-upsert: true
    """
    url = f"{supabase_url.rstrip('/')}/storage/v1/object/{bucket}/{storage_path}"
    content_type, _ = mimetypes.guess_type(str(file_path))
    if not content_type:
        if file_path.suffix.lower() == '.kmz':
            content_type = 'application/vnd.google-earth.kmz'
        elif file_path.suffix.lower() == '.pdf':
            content_type = 'application/pdf'
        else:
            content_type = 'application/octet-stream'

    with open(file_path, 'rb') as f:
        file_bytes = f.read()

    req = urllib.request.Request(url, data=file_bytes, method='POST')
    req.add_header('Authorization', f'Bearer {service_key}')
    req.add_header('apiKey', service_key)
    req.add_header('x-upsert', 'true')
    req.add_header('Content-Type', content_type)

    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status in (200, 201)
    except urllib.error.HTTPError as e:
        err_body = e.read().decode('utf-8', errors='ignore')
        print(f"  [ERROR] Upload storage {storage_path} gagal: HTTP {e.code} - {err_body}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"  [ERROR] Upload storage {storage_path} gagal: {e}", file=sys.stderr)
        return False


def upsert_cluster_record(supabase_url: str, service_key: str, record: dict) -> bool:
    """
    Upsert metadata ke tabel public.cluster_maps via REST API PostgREST.
    POST /rest/v1/cluster_maps dengan Prefer: resolution=merge-duplicates
    """
    url = f"{supabase_url.rstrip('/')}/rest/v1/cluster_maps"
    payload = json.dumps(record).encode('utf-8')

    req = urllib.request.Request(url, data=payload, method='POST')
    req.add_header('Authorization', f'Bearer {service_key}')
    req.add_header('apiKey', service_key)
    req.add_header('Content-Type', 'application/json')
    req.add_header('Prefer', 'resolution=merge-duplicates,return=representation')

    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status in (200, 201)
    except urllib.error.HTTPError as e:
        err_body = e.read().decode('utf-8', errors='ignore')
        print(f"  [ERROR] Upsert cluster_maps {record['cluster_code']} gagal: HTTP {e.code} - {err_body}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"  [ERROR] Upsert cluster_maps {record['cluster_code']} gagal: {e}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(description="Upload massal KMZ dan PDF Cluster ke Supabase Storage & Database")
    parser.add_argument("--dir", required=True, help="Path ke folder root KAB.CILACAP hasil unduh Drive")
    parser.add_argument("--url", default=os.getenv("SUPABASE_URL"), help="Supabase project URL")
    parser.add_argument("--key", default=os.getenv("SUPABASE_SERVICE_KEY"), help="Supabase service role key")

    args = parser.parse_args()

    supabase_url = args.url
    service_key = args.key

    if not supabase_url or not service_key:
        print("[FATAL] SUPABASE_URL atau SUPABASE_SERVICE_KEY belum diatur!", file=sys.stderr)
        print("Setel environment variable atau gunakan argumen --url dan --key.", file=sys.stderr)
        sys.exit(1)

    root_dir = Path(args.dir)
    if not root_dir.exists() or not root_dir.is_dir():
        print(f"[FATAL] Direktori tidak ditemukan: {root_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"=== Memulai Scanning Direktori: {root_dir} ===")

    subfolders = [p for p in root_dir.iterdir() if p.is_dir()]
    if not subfolders:
        print("[WARN] Tidak ada subfolder ditemukan di direktori tersebut.")
        sys.exit(0)

    print(f"Ditemukan {len(subfolders)} subfolder untuk diproses.\n")

    total_success = 0
    total_failed = 0
    missing_kmz = 0
    missing_pdf = 0

    for idx, folder in enumerate(subfolders, start=1):
        parsed = parse_cluster_folder_name(folder.name)
        if not parsed:
            print(f"[{idx}/{len(subfolders)}] [LEWATI] Tidak ada kode XLCLPxxxx di folder: '{folder.name}'")
            total_failed += 1
            continue

        code = parsed['code']
        print(f"[{idx}/{len(subfolders)}] Memproses {code}: '{parsed['name']}'")

        # Cari file KMZ
        kmz_files = list(folder.glob("*.kmz"))
        if not kmz_files:
            kmz_files = list(folder.glob("**/*.kmz"))

        if not kmz_files:
            print(f"  [PERINGATAN] File KMZ tidak ditemukan untuk {code}!")
            missing_kmz += 1
            total_failed += 1
            continue

        kmz_file = kmz_files[0]
        kmz_size = kmz_file.stat().st_size
        kmz_storage_path = f"kmz/{code}.kmz"

        # Cari file PDF
        pdf_files = list(folder.glob("*.pdf"))
        if not pdf_files:
            pdf_files = list(folder.glob("**/*.pdf"))

        pdf_storage_path = None
        if pdf_files:
            pdf_file = pdf_files[0]
            pdf_storage_path = f"pdf/{code}.pdf"
        else:
            missing_pdf += 1

        # 1. Upload KMZ
        print(f"  -> Mengunggah KMZ ({kmz_size / 1024:.1f} KB)...")
        ok_kmz = upload_to_storage(supabase_url, service_key, 'cluster-maps', kmz_storage_path, kmz_file)
        if not ok_kmz:
            total_failed += 1
            continue

        # 2. Upload PDF (bila ada)
        if pdf_storage_path and pdf_files:
            print(f"  -> Mengunggah PDF ({pdf_files[0].stat().st_size / 1024:.1f} KB)...")
            ok_pdf = upload_to_storage(supabase_url, service_key, 'cluster-maps', pdf_storage_path, pdf_files[0])
            if not ok_pdf:
                print(f"  [WARN] Gagal mengunggah PDF untuk {code}, data KMZ tetap disimpan.")
                pdf_storage_path = None

        # 3. Upsert Metadata ke Database
        record = {
            'cluster_code': code,
            'name': parsed['name'],
            'kelurahan': parsed['kelurahan'],
            'rw': parsed['rw'],
            'kmz_path': kmz_storage_path,
            'pdf_path': pdf_storage_path,
            'kmz_size': kmz_size
        }
        ok_db = upsert_cluster_record(supabase_url, service_key, record)
        if ok_db:
            print(f"  [SUKSES] Cluster {code} berhasil disimpan.\n")
            total_success += 1
        else:
            total_failed += 1

    print("=== RINGKASAN PROSES UPLOAD CLUSTER ===")
    print(f"Total Subfolder  : {len(subfolders)}")
    print(f"Berhasil Disimpan: {total_success}")
    print(f"Gagal / Dilewati : {total_failed}")
    print(f"Tidak ada KMZ    : {missing_kmz}")
    print(f"Tidak ada PDF    : {missing_pdf}")
    print("=======================================")


if __name__ == "__main__":
    main()

