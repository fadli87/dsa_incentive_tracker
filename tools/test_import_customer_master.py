import io
import json
import os
import tempfile
import unittest
import zipfile

from tools.import_customer_master import (
    format_summary,
    generate_sql_batches,
    normalize_person_name,
    parse_coordinates,
    parse_html_description,
    parse_install_date,
    parse_kml_bytes,
    read_kml_bytes,
    validate_cli_security,
)


def _make_placemark_html(fields: dict) -> str:
    rows = "".join(f"<tr><td>{k}</td><td>{v}</td></tr>" for k, v in fields.items())
    return f"<![CDATA[<table>{rows}</table>]]>"


def _build_sample_kml() -> bytes:
    p1 = _make_placemark_html({
        "Customer ID": "100001",
        "City Code Homepass": "KCLP",
        "Install Date": "2026-09-10 14:22:00",
        "Homepass Address": "JL.  GATOT SUBROTO  NO 10 CILACAP",
        "Product Name": "XL SATU FWA 50MBPS",
        "Latitude": "-7.71234",
        "Longitude": "109.01234",
        "Sales Name": "  budi   santoso ",
        "SPV Name": " eko  yunianto ",
        "TSC Name": " pipien  malviana ",
        "Serial Number (ONT)": "SN-ONT-SECRET-999111",
        "Serial Number (Wifi)": "SN-WIFI-SECRET-888222",
        "SIM CARD 1": "8962110099887766",
        "WO ID": "WO-SECRET-12345",
        "SO Number": "SO-SECRET-54321",
        "Create Time": "2026-09-09 08:00:00",
        "Close Time": "2026-09-10 15:00:00",
    })
    # Duplicate of 100001 with newer Install Date -> should win dedup
    p1_newer = _make_placemark_html({
        "Customer ID": "100001",
        "City Code Homepass": "KCLP",
        "Install Date": "2026-09-20",
        "Homepass Address": "JL. GATOT SUBROTO NO 10B CILACAP",
        "Product Name": "XL SATU FWA 100MBPS",
        "Latitude": "-7.71500",
        "Longitude": "109.01500",
        "Sales Name": "budi santoso",
        "SPV Name": "eko yunianto",
        "TSC Name": "pipien malviana",
        "Serial Number (ONT)": "SN-ONT-SECRET-NEW",
    })
    # Different city (KPWT) -> should be filtered out when city=KCLP
    p2_other_city = _make_placemark_html({
        "Customer ID": "200002",
        "City Code Homepass": "KPWT",
        "Install Date": "2026-09-15",
        "Homepass Address": "JL. SUDIRMAN PURWOKERTO",
        "Product Name": "XL SATU FWA",
        "Latitude": "-7.42111",
        "Longitude": "109.23444",
        "Sales Name": "ANDI WIJAYA",
    })
    # KCLP record with invalid install date & 0 coordinates & fallback coordinates 0,0
    p3_edge = _make_placemark_html({
        "Customer ID": "100003",
        "City Code Homepass": "KCLP",
        "Install Date": "INVALID-DATE",
        "Homepass Address": "JL. LAUT CILACAP",
        "Product Name": "XL SATU FWA",
        "Latitude": "0",
        "Longitude": "0",
        "Sales Name": "",
        "SPV Name": "rizki ade saputra",
        "TSC Name": "dipta kumala utama",
    })
    # KCLP record with empty HTML Latitude/Longitude that falls back to <coordinates>
    p4_fallback_coord = _make_placemark_html({
        "Customer ID": "100004",
        "City Code Homepass": "KCLP",
        "Install Date": "2026-09-12",
        "Homepass Address": "JL. AHMAD YANI CILACAP",
        "Product Name": "XL SATU FWA",
        "Latitude": "",
        "Longitude": "",
        "Sales Name": "siti   aminah",
        "SPV Name": "eko yunianto",
        "TSC Name": "pipien malviana",
    })

    kml_str = f"""<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>100001</name>
      <description>{p1}</description>
      <Point><coordinates>109.01234,-7.71234,0</coordinates></Point>
    </Placemark>
    <Placemark>
      <name>100001-dup</name>
      <description>{p1_newer}</description>
      <Point><coordinates>109.01500,-7.71500,0</coordinates></Point>
    </Placemark>
    <Placemark>
      <name>200002</name>
      <description>{p2_other_city}</description>
      <Point><coordinates>109.23444,-7.42111,0</coordinates></Point>
    </Placemark>
    <Placemark>
      <name>100003</name>
      <description>{p3_edge}</description>
      <Point><coordinates>0,0,0</coordinates></Point>
    </Placemark>
    <Placemark>
      <name>100004</name>
      <description>{p4_fallback_coord}</description>
      <Point><coordinates>109.05555,-7.68888,0</coordinates></Point>
    </Placemark>
  </Document>
</kml>"""
    return kml_str.encode("utf-8")


class TestImportCustomerMaster(unittest.TestCase):
    def test_whitelist_and_sensitive_fields_discarded(self):
        kml_bytes = _build_sample_kml()
        records, stats = parse_kml_bytes(kml_bytes, target_city="KCLP", batch_id="2026-09-27")

        serialized_json = json.dumps(records)
        sql_chunks = "\n".join(generate_sql_batches(records))
        summary_text = format_summary(stats)

        for secret in (
            "SN-ONT-SECRET-999111",
            "SN-ONT-SECRET-NEW",
            "SN-WIFI-SECRET-888222",
            "8962110099887766",
            "WO-SECRET-12345",
            "SO-SECRET-54321",
        ):
            self.assertNotIn(secret, serialized_json)
            self.assertNotIn(secret, sql_chunks)
            self.assertNotIn(secret, summary_text)

    def test_city_filter_dedup_normalization_and_stats(self):
        kml_bytes = _build_sample_kml()
        records, stats = parse_kml_bytes(kml_bytes, target_city="KCLP", batch_id="2026-09-27")

        # 5 placemarks total, 4 KCLP (1 duplicate -> 3 unique KCLP records)
        self.assertEqual(stats["total_placemarks"], 5)
        self.assertEqual(stats["city_matched"], 4)
        self.assertEqual(stats["valid_unique_records"], 3)
        self.assertEqual(stats["duplicate_count"], 1)
        self.assertEqual(stats["missing_coords"], 1)
        self.assertEqual(stats["missing_install_date"], 1)
        self.assertEqual(stats["missing_sales_name"], 1)
        self.assertEqual(stats["unique_sales_count"], 2)
        self.assertEqual(stats["min_install_date"], "2026-09-12")
        self.assertEqual(stats["max_install_date"], "2026-09-20")

        by_id = {r["customer_id"]: r for r in records}
        self.assertNotIn("200002", by_id)  # KPWT filtered out

        # Dedup picked newer 2026-09-20 for 100001
        r1 = by_id["100001"]
        self.assertEqual(r1["install_date"], "2026-09-20")
        self.assertEqual(r1["package_name"], "XL SATU FWA 100MBPS")
        self.assertEqual(r1["sales_name"], "BUDI SANTOSO")
        self.assertEqual(r1["spv_name"], "EKO YUNIANTO")
        self.assertEqual(r1["tsc_name"], "PIPIEN MALVIANA")

        # Invalid date and 0,0 coordinates become None
        r3 = by_id["100003"]
        self.assertIsNone(r3["install_date"])
        self.assertIsNone(r3["latitude"])
        self.assertIsNone(r3["longitude"])
        self.assertEqual(r3["sales_name"], "")

        # Fallback from <coordinates> works when HTML Latitude/Longitude are empty
        r4 = by_id["100004"]
        self.assertAlmostEqual(r4["latitude"], -7.68888, places=5)
        self.assertAlmostEqual(r4["longitude"], 109.05555, places=5)
        self.assertEqual(r4["sales_name"], "SITI AMINAH")

    def test_kmz_archive_reading(self):
        kml_bytes = _build_sample_kml()
        with tempfile.NamedTemporaryFile(suffix=".kmz", delete=False) as tmp:
            tmp_path = tmp.name
        try:
            with zipfile.ZipFile(tmp_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
                zf.writestr("doc.kml", kml_bytes)
            loaded = read_kml_bytes(tmp_path)
            self.assertEqual(loaded, kml_bytes)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def test_cli_security_rejects_secrets_in_args(self):
        with self.assertRaises(RuntimeError):
            validate_cli_security(["--input", "a.kmz", "--service-key", "secret"])
        with self.assertRaises(RuntimeError):
            validate_cli_security(["--input", "a.kmz", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.abc"])
        with self.assertRaises(RuntimeError):
            validate_cli_security(["--input", "https://xyz.supabase.co"])
        # Safe args should pass without raising
        validate_cli_security(["--input", "private_data/fwa.kmz", "--dry-run"])


if __name__ == "__main__":
    unittest.main()

