# Aturan Versi Aplikasi (Semantic Versioning 0-9 Rollover)

Aplikasi ini menggunakan format versi **`Major.Minor.Patch`** (misal: `1.1.0`, tampilan: `v1.1.0` / `Ver.1.1.0`) dengan ketentuan khusus sebagai berikut:

## 1. Batas Maksimal Angka per Segmen (Top Digit = 9)
- **Patch (X.Y.Z)**: Nilai digit berada pada rentang **0 hingga 9**.
  - Jika versi saat ini adalah `1.0.9` dan ada update rilis baru, versi **TIDAK** menjadi `1.0.10`, melainkan naik (rollover) ke **`1.1.0`**.
  - Contoh alur: `1.0.8` ➔ `1.0.9` ➔ **`1.1.0`** ➔ `1.1.1` ... ➔ `1.1.9` ➔ **`1.2.0`**.
- **Minor (X.Y.0)**: Nilai digit berada pada rentang **0 hingga 9**.
  - Jika mencapai `1.9.9` dan ada pembaruan berikutnya, naik ke **`2.0.0`**.

## 2. Major Update (2.x.x)
- Versi Major dinaikkan ke **`2.0.0`** (atau `X+1.0.0`) apabila terjadi **perubahan besar (*major update*)** dalam arsitektur atau seluruh fitur utama aplikasi (misal perombakan total UI/UX, database engine baru, atau perubahan fundamental skema bisnis).

## 3. Lokasi Sinkronisasi Versi Wajib
Saat menaikkan versi, selalu perbarui file-file berikut secara serentak:
1. [lib/core/constants/app_constants.dart](file:///c:/DevApp/dsa_incentive_tracker/lib/core/constants/app_constants.dart) (`appVersion`, `appVersionDisplay`, `copyrightSubtext`).
2. [pubspec.yaml](file:///c:/DevApp/dsa_incentive_tracker/pubspec.yaml) (`version: X.Y.Z+build`).
3. [windows_installer.iss](file:///c:/DevApp/dsa_incentive_tracker/windows_installer.iss) (`#define MyAppVersion "X.Y.Z"`).
4. [build_windows_installer.bat](file:///c:/DevApp/dsa_incentive_tracker/build_windows_installer.bat) (nama file output installer).
5. [lib/ui/screens/update_notes_screen.dart](file:///c:/DevApp/dsa_incentive_tracker/lib/ui/screens/update_notes_screen.dart) (catatan rilis terbaru).
