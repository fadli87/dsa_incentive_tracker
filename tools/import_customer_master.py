#!/usr/bin/env python3
"""
Skrip Impor Master Pelanggan KCLP dari file KMZ/KML manajemen ke Supabase.
Hanya menggunakan Python 3 standard library.

Keamanan & Guardrails:
1. HANYA membaca kolom yang ada di WHITELIST. Kolom sensitif seperti Serial Number
   (Wifi/ONT/SIM CARD 1), WO ID, SO Number, Create/Close Time langsung dibuang.
2. Kredensial SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY HANYA dibaca dari
   environment variable, tidak pernah diterima lewat argumen CLI dan tidak pernah dicetak.
"""

import argparse
import datetime
import html
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from typing import Any, Dict, List, Optional, Sequence, Tuple

WHITELIST_HTML_KEYS = frozenset({
    "Customer ID",
    "City Code Homepass",
    "Install Date",
    "Homepass Address",
    "Product Name",
    "Latitude",
    "Longitude",
    "Sales Name",
    "SPV Name",
    "TSC Name",
})

FORBIDDEN_CLI_FLAGS = (
    "--supabase-url",
    "--service-key",
    "--service-role-key",
    "--apikey",
    "--api-key",
    "--key",
    "--token",
)

BATCH_SIZE = 500


def normalize_person_name(value: Optional[str]) -> str:
    """Trim, ubah spasi ganda menjadi satu spasi, dan UPPERCASE."""
    if not value:
        return ""
    cleaned = re.sub(r"\s+", " ", value.strip())
    return cleaned.upper()


def parse_install_date(value: Optional[str]) -> Optional[str]:
    """Ambil 10 karakter pertama format YYYY-MM-DD; kembalikan None bila tidak valid."""
    if not value:
        return None
    candidate = value.strip()[:10]
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", candidate):
        return None
    try:
        datetime.date.fromisoformat(candidate)
        return candidate
    except ValueError:
        return None


def parse_coordinates(
    lat_raw: Optional[Any],
    lon_raw: Optional[Any],
    fallback_lat: Optional[float] = None,
    fallback_lon: Optional[float] = None,
) -> Tuple[Optional[float], Optional[float]]:
    """
    Validasi koordinat dalam rentang lat -90..90, lon -180..180 (dan bukan 0,0 / 0).
    Jika field Latitude/Longitude kosong atau tidak valid, gunakan fallback dari <coordinates>.
    Jika tetap tidak valid atau bernilai 0, kembalikan (None, None).
    """
    def _to_valid_pair(lat_val: Any, lon_val: Any) -> Optional[Tuple[float, float]]:
        if lat_val is None or lon_val is None:
            return None
        try:
            lat_f = float(str(lat_val).strip().replace(",", "."))
            lon_f = float(str(lon_val).strip().replace(",", "."))
        except (ValueError, TypeError):
            return None
        if lat_f == 0.0 or lon_f == 0.0:
            return None
        if not (-90.0 <= lat_f <= 90.0 and -180.0 <= lon_f <= 180.0):
            return None
        return (lat_f, lon_f)

    primary = _to_valid_pair(lat_raw, lon_raw)
    if primary is not None:
        return primary

    fallback = _to_valid_pair(fallback_lat, fallback_lon)
    if fallback is not None:
        return fallback

    return (None, None)


def parse_html_description(desc_html: str) -> Dict[str, str]:
    """
    Ekstrak pasangan kunci-nilai dari tabel HTML <tr><td>Kunci</td><td>Nilai</td></tr>
    dan langsung saring hanya kunci yang masuk WHITELIST_HTML_KEYS.
    """
    if not desc_html:
        return {}
    result: Dict[str, str] = {}
    row_pattern = re.compile(
        r"<tr[^>]*>\s*<t[dh][^>]*>(.*?)</t[dh]>\s*<t[dh][^>]*>(.*?)</t[dh]>\s*</tr>",
        re.IGNORECASE | re.DOTALL,
    )
    tag_strip = re.compile(r"<[^>]+>")
    for match in row_pattern.finditer(desc_html):
        raw_key = tag_strip.sub("", match.group(1))
        raw_val = tag_strip.sub("", match.group(2))
        key = html.unescape(raw_key).strip()
        val = html.unescape(raw_val).strip()
        if key in WHITELIST_HTML_KEYS:
            result[key] = val
    return result


def parse_placemark_point_coordinates(placemark_elem: ET.Element) -> Tuple[Optional[float], Optional[float]]:
    """Baca elemen <coordinates> (lon,lat[,alt]) dari Placemark."""
    for elem in placemark_elem.iter():
        local_name = elem.tag.split("}")[-1] if "}" in elem.tag else elem.tag
        if local_name.lower() == "coordinates" and elem.text:
            coord_text = elem.text.strip().split()[0]
            parts = coord_text.split(",")
            if len(parts) >= 2:
                try:
                    lon = float(parts[0].strip())
                    lat = float(parts[1].strip())
                    return (lat, lon)
                except ValueError:
                    return (None, None)
    return (None, None)


def read_kml_bytes(input_path: str) -> bytes:
    """Baca isi KML baik dari file .kmz (zip) maupun .kml langsung."""
    if zipfile.is_zipfile(input_path):
        with zipfile.ZipFile(input_path, "r") as zf:
            names = zf.namelist()
            kml_names = [n for n in names if n.lower().endswith("doc.kml")] or [
                n for n in names if n.lower().endswith(".kml")
            ]
            if not kml_names:
                raise ValueError("File KMZ tidak memiliki dokumen .kml di dalamnya.")
            return zf.read(kml_names[0])
    with open(input_path, "rb") as f:
        return f.read()


def parse_kml_bytes(
    kml_bytes: bytes,
    target_city: str = "KCLP",
    batch_id: Optional[str] = None,
) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    """
    Parse dokumen KML dan kembalikan (daftar_record_unik, statistik_ringkasan).
    """
    target_city_norm = target_city.strip().upper()
    effective_batch_id = batch_id or datetime.date.today().isoformat()

    root = ET.fromstring(kml_bytes)
    total_placemarks = 0
    city_matched = 0
    duplicate_count = 0

    dedup_map: Dict[str, Dict[str, Any]] = {}

    for elem in root.iter():
        local_name = elem.tag.split("}")[-1] if "}" in elem.tag else elem.tag
        if local_name != "Placemark":
            continue
        total_placemarks += 1

        desc_text = ""
        for child in elem:
            child_name = child.tag.split("}")[-1] if "}" in child.tag else child.tag
            if child_name == "description" and child.text:
                desc_text = child.text
                break

        whitelisted = parse_html_description(desc_text)
        city_code = whitelisted.get("City Code Homepass", "").strip().upper()
        if city_code != target_city_norm:
            continue
        city_matched += 1

        customer_id = whitelisted.get("Customer ID", "").strip()
        if not customer_id:
            continue

        install_date = parse_install_date(whitelisted.get("Install Date"))
        fb_lat, fb_lon = parse_placemark_point_coordinates(elem)
        lat, lon = parse_coordinates(
            whitelisted.get("Latitude"),
            whitelisted.get("Longitude"),
            fallback_lat=fb_lat,
            fallback_lon=fb_lon,
        )

        record: Dict[str, Any] = {
            "customer_id": customer_id,
            "city_code": city_code,
            "install_date": install_date,
            "address": re.sub(r"\s+", " ", whitelisted.get("Homepass Address", "").strip()),
            "package_name": re.sub(r"\s+", " ", whitelisted.get("Product Name", "").strip()),
            "latitude": lat,
            "longitude": lon,
            "sales_name": normalize_person_name(whitelisted.get("Sales Name")),
            "spv_name": normalize_person_name(whitelisted.get("SPV Name")),
            "tsc_name": normalize_person_name(whitelisted.get("TSC Name")),
            "batch_id": effective_batch_id,
        }

        if customer_id in dedup_map:
            duplicate_count += 1
            existing = dedup_map[customer_id]
            old_date = existing.get("install_date") or ""
            new_date = record.get("install_date") or ""
            if new_date >= old_date:
                dedup_map[customer_id] = record
        else:
            dedup_map[customer_id] = record

    records = sorted(dedup_map.values(), key=lambda r: r["customer_id"])

    missing_coords = sum(1 for r in records if r["latitude"] is None or r["longitude"] is None)
    missing_install_date = sum(1 for r in records if r["install_date"] is None)
    missing_sales_name = sum(1 for r in records if not r["sales_name"])
    unique_sales = sorted({r["sales_name"] for r in records if r["sales_name"]})
    valid_dates = sorted(r["install_date"] for r in records if r["install_date"])
    per_tsc: Dict[str, int] = {}
    for r in records:
        tsc_key = r["tsc_name"] or "(TANPA TSC)"
        per_tsc[tsc_key] = per_tsc.get(tsc_key, 0) + 1

    stats: Dict[str, Any] = {
        "total_placemarks": total_placemarks,
        "city_code": target_city_norm,
        "city_matched": city_matched,
        "valid_unique_records": len(records),
        "duplicate_count": duplicate_count,
        "missing_coords": missing_coords,
        "missing_install_date": missing_install_date,
        "missing_sales_name": missing_sales_name,
        "unique_sales_count": len(unique_sales),
        "min_install_date": valid_dates[0] if valid_dates else None,
        "max_install_date": valid_dates[-1] if valid_dates else None,
        "per_tsc": per_tsc,
        "batch_id": effective_batch_id,
    }
    return (records, stats)


def format_summary(stats: Dict[str, Any]) -> str:
    """Format ringkasan statistik untuk terminal tanpa memuat data pribadi pelanggan."""
    date_range = (
        f"{stats['min_install_date']} s/d {stats['max_install_date']}"
        if stats["min_install_date"]
        else "Tidak ada tanggal valid"
    )
    lines = [
        "============================================================",
        f"RINGKASAN IMPOR MASTER PELANGGAN ({stats['city_code']})",
        "============================================================",
        f"Batch ID                  : {stats['batch_id']}",
        f"Total Placemark di file   : {stats['total_placemarks']}",
        f"Jumlah kota {stats['city_code']:<13} : {stats['city_matched']}",
        f"Baris valid (unik)        : {stats['valid_unique_records']}",
        f"Duplikat Customer ID      : {stats['duplicate_count']}",
        f"Tanpa koordinat valid     : {stats['missing_coords']}",
        f"Tanpa tanggal install     : {stats['missing_install_date']}",
        f"Tanpa Sales Name          : {stats['missing_sales_name']}",
        f"Jumlah Sales unik         : {stats['unique_sales_count']}",
        f"Rentang tanggal install   : {date_range}",
        "------------------------------------------------------------",
        "Jumlah per TSC:",
    ]
    for tsc_name, count in sorted(stats["per_tsc"].items()):
        lines.append(f"  - {tsc_name}: {count}")
    lines.append("============================================================")
    return "\n".join(lines)


def _sql_literal(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, (int, float)):
        return repr(float(value))
    text = str(value).replace("'", "''")
    return f"'{text}'"


def generate_sql_batches(
    records: Sequence[Dict[str, Any]],
    batch_size: int = BATCH_SIZE,
) -> List[str]:
    """Hasilkan daftar string SQL upsert per 500 baris."""
    if not records:
        return []
    columns = (
        "customer_id",
        "city_code",
        "install_date",
        "address",
        "package_name",
        "latitude",
        "longitude",
        "sales_name",
        "spv_name",
        "tsc_name",
        "batch_id",
    )
    sql_chunks: List[str] = []
    for i in range(0, len(records), batch_size):
        chunk = records[i : i + batch_size]
        values_rows: List[str] = []
        for r in chunk:
            vals = ", ".join(_sql_literal(r.get(col)) for col in columns)
            values_rows.append(f"  ({vals})")
        values_block = ",\n".join(values_rows)
        stmt = (
            f"insert into public.customer_master ({', '.join(columns)})\n"
            f"values\n{values_block}\n"
            "on conflict (customer_id) do update set\n"
            "  city_code = excluded.city_code,\n"
            "  install_date = excluded.install_date,\n"
            "  address = excluded.address,\n"
            "  package_name = excluded.package_name,\n"
            "  latitude = excluded.latitude,\n"
            "  longitude = excluded.longitude,\n"
            "  sales_name = excluded.sales_name,\n"
            "  spv_name = excluded.spv_name,\n"
            "  tsc_name = excluded.tsc_name,\n"
            "  batch_id = excluded.batch_id,\n"
            "  imported_at = now();\n"
        )
        sql_chunks.append(stmt)
    return sql_chunks


def write_sql_files(
    records: Sequence[Dict[str, Any]],
    sql_out_pattern: str,
    batch_size: int = BATCH_SIZE,
) -> List[str]:
    """Tulis file SQL per batch (500 baris) ke path yang diminta."""
    chunks = generate_sql_batches(records, batch_size=batch_size)
    written_files: List[str] = []
    base, ext = os.path.splitext(sql_out_pattern)
    if not ext:
        ext = ".sql"
    for idx, sql_text in enumerate(chunks, start=1):
        if len(chunks) == 1:
            out_path = f"{base}{ext}"
        else:
            if base.endswith("_NN"):
                out_path = f"{base[:-3]}_{idx:02d}{ext}"
            else:
                out_path = f"{base}_{idx:02d}{ext}"
        parent_dir = os.path.dirname(out_path)
        if parent_dir:
            os.makedirs(parent_dir, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(sql_text)
        written_files.append(out_path)
    return written_files


def validate_cli_security(argv: Sequence[str]) -> None:
    """Tolak argumen CLI yang mencoba mengirim URL Supabase atau Service Key."""
    for arg in argv:
        lower = arg.lower()
        for flag in FORBIDDEN_CLI_FLAGS:
            if lower == flag or lower.startswith(flag + "="):
                raise RuntimeError(
                    f"KEAMANAN: Argumen '{flag}' dilarang di CLI. "
                    "Gunakan environment variable SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY."
                )
        if "supabase.co" in lower or arg.startswith("eyJ"):
            raise RuntimeError(
                "KEAMANAN: Jangan melewatkan URL Supabase atau JWT key di argumen CLI. "
                "Gunakan environment variable SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY."
            )


def _request_with_retry(
    req: urllib.request.Request,
    timeout: int = 30,
    max_retries: int = 3,
) -> Tuple[int, bytes]:
    last_err: Optional[Exception] = None
    for attempt in range(1, max_retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return (resp.status, resp.read())
        except urllib.error.HTTPError as e:
            if e.code >= 500 and attempt < max_retries:
                time.sleep(attempt * 1.5)
                last_err = e
                continue
            raise RuntimeError(f"HTTP {e.code} saat menghubungi Supabase REST.") from None
        except urllib.error.URLError as e:
            last_err = e
            if attempt < max_retries:
                time.sleep(attempt * 1.5)
                continue
            raise RuntimeError(f"Gagal jaringan saat menghubungi Supabase REST: {e.reason}") from None
    raise RuntimeError(f"Permintaan gagal setelah {max_retries} percobaan: {last_err}")


def upsert_to_supabase(
    records: Sequence[Dict[str, Any]],
    supabase_url: str,
    service_role_key: str,
    batch_size: int = BATCH_SIZE,
) -> int:
    """Kirim baris ke Supabase REST dalam batch 500 baris."""
    base_url = supabase_url.rstrip("/")
    endpoint = f"{base_url}/rest/v1/customer_master?on_conflict=customer_id"
    total_sent = 0

    for i in range(0, len(records), batch_size):
        chunk = records[i : i + batch_size]
        payload = json.dumps(chunk).encode("utf-8")
        req = urllib.request.Request(
            endpoint,
            data=payload,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates,return=minimal",
                "apikey": service_role_key,
                "Authorization": f"Bearer {service_role_key}",
            },
        )
        _request_with_retry(req)
        total_sent += len(chunk)
        print(f"  [Upsert] Terkirim {total_sent}/{len(records)} baris...")

    return total_sent


def report_missing_in_new_file(
    new_records: Sequence[Dict[str, Any]],
    supabase_url: str,
    service_role_key: str,
    city_code: str = "KCLP",
) -> int:
    """
    Bandingkan Customer ID di file baru dengan yang ada di tabel customer_master Supabase.
    Hanya melaporkan jumlah pelanggan yang tidak ada lagi di file baru (tidak menghapus).
    """
    base_url = supabase_url.rstrip("/")
    new_ids = {r["customer_id"] for r in new_records}
    existing_ids = set()
    page_size = 1000
    offset = 0
    city_param = urllib.parse.quote(city_code.strip().upper())

    while True:
        endpoint = (
            f"{base_url}/rest/v1/customer_master"
            f"?select=customer_id&city_code=eq.{city_param}&order=customer_id.asc"
        )
        req = urllib.request.Request(
            endpoint,
            method="GET",
            headers={
                "apikey": service_role_key,
                "Authorization": f"Bearer {service_role_key}",
                "Range-Unit": "items",
                "Range": f"{offset}-{offset + page_size - 1}",
            },
        )
        _, body = _request_with_retry(req)
        rows = json.loads(body.decode("utf-8"))
        if not rows:
            break
        for row in rows:
            cid = row.get("customer_id")
            if cid:
                existing_ids.add(str(cid))
        if len(rows) < page_size:
            break
        offset += page_size

    missing_ids = existing_ids - new_ids
    print(
        f"[Report Missing] Pelanggan di DB ({city_code}): {len(existing_ids)} | "
        f"Tidak ada lagi di file baru: {len(missing_ids)} (TIDAK dihapus otomatis)."
    )
    return len(missing_ids)


def main(argv: Optional[Sequence[str]] = None) -> int:
    raw_argv = list(sys.argv[1:] if argv is None else argv)
    validate_cli_security(raw_argv)

    parser = argparse.ArgumentParser(
        description="Impor Master Pelanggan KCLP dari KMZ/KML ke Supabase."
    )
    parser.add_argument("--input", required=True, help="Path ke file .kmz atau .kml")
    parser.add_argument("--city", default="KCLP", help="Kode kota Homepass (default: KCLP)")
    parser.add_argument(
        "--batch-id",
        default=datetime.date.today().isoformat(),
        help="ID batch impor (default: YYYY-MM-DD hari ini)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Hanya cetak ringkasan tanpa menulis ke DB atau file (default bila tidak ada mode)",
    )
    parser.add_argument(
        "--upsert",
        action="store_true",
        help="Kirim langsung ke Supabase REST menggunakan env SUPABASE_URL & SUPABASE_SERVICE_ROLE_KEY",
    )
    parser.add_argument(
        "--sql-out",
        default=None,
        help="Hasilkan file SQL upsert per 500 baris (contoh: private_data/customer_master_batch_NN.sql)",
    )
    parser.add_argument(
        "--report-missing",
        action="store_true",
        help="Laporkan jumlah pelanggan di DB yang tidak ada lagi di file baru (tanpa menghapus)",
    )
    parser.add_argument(
        "--yes",
        "-y",
        action="store_true",
        help="Lewati konfirmasi y/N saat menjalankan --upsert",
    )

    args = parser.parse_args(raw_argv)

    if not os.path.isfile(args.input):
        print(f"ERROR: File tidak ditemukan: {args.input}", file=sys.stderr)
        return 1

    kml_bytes = read_kml_bytes(args.input)
    records, stats = parse_kml_bytes(
        kml_bytes,
        target_city=args.city,
        batch_id=args.batch_id,
    )
    print(format_summary(stats))

    if args.sql_out:
        written = write_sql_files(records, args.sql_out, batch_size=BATCH_SIZE)
        print(f"[SQL Out] Berhasil menulis {len(written)} file SQL:")
        for p in written:
            print(f"  - {p}")

    if args.upsert or args.report_missing:
        supabase_url = os.environ.get("SUPABASE_URL", "").strip()
        service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not supabase_url or not service_key:
            print(
                "ERROR: Environment variable SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY wajib diisi.",
                file=sys.stderr,
            )
            return 1

        if args.upsert:
            if not args.yes:
                ans = input(
                    f"Kirim {len(records)} baris ({args.city}) ke Supabase sekarang? [y/N]: "
                ).strip().lower()
                if ans != "y":
                    print("Upsert dibatalkan oleh pengguna.")
                    return 0
            upsert_to_supabase(records, supabase_url, service_key, batch_size=BATCH_SIZE)
            print(f"[Upsert Selesai] {len(records)} baris telah di-upsert.")

        if args.report_missing:
            report_missing_in_new_file(records, supabase_url, service_key, city_code=args.city)

    return 0


if __name__ == "__main__":
    sys.exit(main())

