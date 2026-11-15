# Script Upload Massal Peta Cluster ke Supabase

Script ini digunakan untuk mengunggah seluruh file KMZ dan PDF rancangan cluster (ABD) dari Google Drive (`KAB.CILACAP`) ke Supabase Storage (bucket privat `cluster-maps`) dan mencatat metadatanya ke tabel `public.cluster_maps`.

## Persyaratan
- Python 3.8+ (menggunakan pustaka standar Python, tanpa dependensi eksternal).
- Supabase Project URL dan Service Role Key (`SUPABASE_SERVICE_KEY`).

## Cara Penggunaan

1. Siapkan folder `KAB.CILACAP` yang diunduh dari Google Drive di komputer Anda.
   Struktur folder:
   ```text
   KAB.CILACAP/
   ├── CLUSTER INTAN RESIDENCE, KELURAHAN GUMILIR RW 17 - XLCLP1947/
   │   ├── ABD - KELURAHAN GUMILIR RW 17 DSK - XLCLP1947.kmz
   │   └── ABD - KELURAHAN GUMILIR RW 17 DSK - XLCLP1947.pdf
   ├── PERUMAHAN TAMAN JUANDA - XLCLP1161/
   │   ├── ABD - PERUMAHAN TAMAN JUANDA - XLCLP1161.kmz
   │   └── ABD - PERUMAHAN TAMAN JUANDA - XLCLP1161.pdf
   └── ...
   ```

2. Jalankan perintah di terminal:

```bash
# Set environment variables
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_KEY="your-service-role-key"

# Jalankan upload massal
python tools/upload_cluster_maps/upload_cluster_maps.py --dir "/path/ke/KAB.CILACAP"
```

Di Windows PowerShell:
```powershell
$env:SUPABASE_URL="https://your-project.supabase.co"
$env:SUPABASE_SERVICE_KEY="your-service-role-key"

python tools/upload_cluster_maps/upload_cluster_maps.py --dir "C:\path\ke\KAB.CILACAP"
```

## Sifat Idempoten
Script ini aman dijalankan berulang kali:
- File Storage yang sudah ada akan ditimpa (`upsert: true`).
- Record database akan diperbarui (`merge-duplicates`) dan `updated_at` direset ke waktu saat ini.
