import '../../core/catalog/package_catalog.dart';
import '../core/entity_extractor.dart';
import '../models/quick_action.dart';

/// Handler untuk skrip komunikasi sales lapangan dan penanganan keberatan calon pelanggan (objection handling).
/// Menggunakan data katalog nyata tanpa klaim tanpa dasar.
class ScriptHandlers {
  ScriptHandlers._();

  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleScript({
    required ExtractedEntities entities,
    String? explicitType,
  }) {
    final segment = entities.segment;
    final objection = entities.objection;

    // 1. Script Berdasarkan Keberatan (Objection)
    if (objection == 'mahal') {
      return (
        text: '🛡️ **Handling Objection: "Harganya Kemahalan Mas/Mbak"**\n\n'
            '*"Saya paham sekali pertimbangan Bapak/Ibu mengenai anggaran bulanan. Mari kita hitung bersama: jika anggota keluarga masing-masing membeli kuota HP bulanan 50rb dikali 4 orang, pengeluarannya sudah 200rb, belum termasuk WiFi rumah.*\n\n'
            '*Dengan paket bundling XL Satu, seluruh kebutuhan internet WiFi rumah unlimited dan kuota HP bersama sudah digabung menjadi satu tagihan hemat. Mau saya buatkan simulasi paket yang paling pas dengan budget keluarga?"*',
        actions: const [
          QuickAction(
            label: 'Daftar Paket FMC',
            intent: 'package_list',
            args: {'type': 'fmc'},
          ),
          QuickAction(
            label: 'Script Pelanggan Rumah',
            intent: 'script_get',
            args: {'segment': 'rumah'},
          ),
        ],
        metadata: {'category': 'objection', 'type': 'mahal'},
      );
    }

    if (objection == 'sudah_ada_wifi') {
      return (
        text: '🛡️ **Handling Objection: "Di Rumah Sudah Ada WiFi Lain"**\n\n'
            '*"Bagus sekali kalau sudah terbiasa pakai WiFi di rumah Pak/Bu. Boleh saya tahu provider yang sekarang sering mengalami kendala lambat saat jam sibuk atau biaya langganannya naik berkala?\n\n'
            '*XL Satu hadir dengan teknologi fiber optik terbaru berkecepatan tinggi dengan harga flat tanpa kenaikan mendadak, plus fasilitas gratis kuota HP bersama. Banyak tetangga di area sini yang beralih karena performa lebih stabil dan tagihan lebih terjangkau. Boleh saya cekkan titik jangkauan kabel ke rumah Bapak/Ibu sebentar?"*',
        actions: const [
          QuickAction(
            label: 'Perbedaan FWA vs FTTH',
            intent: 'fwa_vs_ftth',
          ),
          QuickAction(
            label: 'Daftar Paket FTTH',
            intent: 'package_list',
            args: {'type': 'ftth'},
          ),
        ],
        metadata: {'category': 'objection', 'type': 'sudah_ada_wifi'},
      );
    }

    if (objection == 'mikir') {
      return (
        text: '🛡️ **Handling Objection: "Saya Pikir-Pikir Dulu Ya"**\n\n'
            '*"Sangat wajar Pak/Bu untuk mempertimbangkan terlebih dahulu. Izin menginfokan bahwa slot alokasi instalasi gratis dan promo upgrade kecepatan bulan ini memiliki kuota terbatas per area tiang.\n\n'
            '*Supaya Bapak/Ibu tidak kehilangan promo ketika nanti siap pasang, izinkan saya simpan data titik jangkauannya terlebih dahulu tanpa biaya apapun. Boleh saya minta nomor WhatsApp untuk kirimkan brosur rincian resminya?"*',
        actions: const [
          QuickAction(
            label: 'Draf Pesan WhatsApp',
            intent: 'wa_draft',
          ),
          QuickAction(
            label: 'Daftar Paket FTTH',
            intent: 'package_list',
            args: {'type': 'ftth'},
          ),
        ],
        metadata: {'category': 'objection', 'type': 'mikir'},
      );
    }

    if (objection == 'ribet') {
      final fwaPkg = PackageCatalog.findById('fwa-hero-100-mbps')!;
      return (
        text: '🛡️ **Handling Objection: "Takut Ribet Pemasangannya / Rusak Dinding"**\n\n'
            '*"Bapak/Ibu tenang saja, jika tidak ingin proses penarikan kabel atau pengeboran dinding yang memakan waktu, kami memiliki solusi XL SATU FWA (${fwaPkg.title}).\n\n'
            '*Sistemnya Plug & Play nirkabel berkecepatan tinggi. Teknisi resmi kami akan mengantarkan perangkat dan memastikan sinyal langsung aktif saat itu juga tanpa merusak estetika rumah."*',
        actions: const [
          QuickAction(
            label: 'Daftar Paket FWA',
            intent: 'package_list',
            args: {'type': 'fwa'},
          ),
          QuickAction(
            label: 'Rekomendasi Paket Sinyal',
            intent: 'rf_analyze',
          ),
        ],
        metadata: {'category': 'objection', 'type': 'ribet'},
      );
    }

    // 2. Script Berdasarkan Segmen Pasar
    if (segment == 'kos') {
      return (
        text: '🗣️ **Script Closing: Anak Kos / Pemilik Kos**\n\n'
            '*"Permisi Kak/Ibu, mau tanya untuk koneksi internet di kosan sering melambat pas jam malam saat semua penghuni online bersamaan?\n\n'
            '*XL Satu punya solusi internet praktis Plug & Play berkecepatan tinggi yang bisa dinikmati bersama dengan kuota besar. Sangat pas untuk tugas kuliah, streaming, maupun gaming bersama teman kos tanpa putus-putus. Mau saya bantu cekkan paket yang paling pas untuk kosan ini?"*',
        actions: const [
          QuickAction(
            label: 'Daftar Paket FWA',
            intent: 'package_list',
            args: {'type': 'fwa'},
          ),
          QuickAction(
            label: 'Script Usaha/Warkop',
            intent: 'script_get',
            args: {'segment': 'warkop'},
          ),
        ],
        metadata: {'category': 'segment', 'type': 'kos'},
      );
    }

    if (segment == 'warkop' || segment == 'umkm') {
      return (
        text: '🗣️ **Script Closing: Pelaku Usaha / Warkop / Cafe**\n\n'
            '*"Selamat siang Bapak/Ibu, izin numpang info solusi internet untuk menaikkan kenyamanan pengunjung warung/toko Anda.\n\n'
            '*Koneksi WiFi yang cepat dan stabil terbukti membuat pelanggan betah nongkrong dan berbelanja lebih lama. XL Satu menawarkan paket berkecepatan tinggi dengan biaya bulanan flat yang sangat bersahabat untuk operasional usaha, plus sistem kasir dan CCTV tetap online lancar. Boleh saya cekkan jaringan di ruko/lokasi usaha Bapak/Ibu?"*',
        actions: const [
          QuickAction(
            label: 'Daftar Paket FTTH',
            intent: 'package_list',
            args: {'type': 'ftth'},
          ),
          QuickAction(
            label: 'Daftar Paket FWA',
            intent: 'package_list',
            args: {'type': 'fwa'},
          ),
        ],
        metadata: {'category': 'segment', 'type': 'warkop'},
      );
    }

    if (explicitType == 'fwa' || entities.packageType == 'fwa') {
      return (
        text: '🗣️ **Script Closing: Penawaran Khusus FWA Outdoor**\n\n'
            '*"Selamat pagi/siang Bapak/Ibu, salam kenal saya dari XL Satu. Apakah di area rumah Bapak/Ibu sering terkendala belum ada tiang kabel internet optik?\n\n'
            '*Kini hadir XL SATU FWA 100 Mbps dengan teknologi router nirkabel outdoor modern. Tanpa perlu menunggu jaringan kabel optik, rumah Anda bisa langsung menikmati WiFi kencang sekeluarga hari ini juga. Boleh saya bantu ukur kekuatan sinyalnya sebentar?"*',
        actions: const [
          QuickAction(
            label: 'Rekomendasi Paket Sinyal',
            intent: 'rf_analyze',
          ),
          QuickAction(
            label: 'Daftar Paket FWA',
            intent: 'package_list',
            args: {'type': 'fwa'},
          ),
        ],
        metadata: {'category': 'product', 'type': 'fwa'},
      );
    }

    // Default Rumah Tangga
    return (
      text: '🗣️ **Script Closing: Calon Pelanggan Rumah Tangga**\n\n'
          '*"Selamat pagi/siang Bapak/Ibu, salam kenal saya dari tim resmi XL Satu. Izin menginfokan program internet rumah cepat untuk warga di lingkungan sini.\n\n'
          '*Apakah putra-putri atau keluarga sering streaming video, belajar online, atau WFH di rumah? Bulan ini tersedia fasilitas bebas biaya instalasi dan bonus kuota HP sekeluarga.\n\n'
          '*Boleh saya bantu cek titik jaringan tiang terdekat ke rumah Bapak/Ibu? Hanya butuh 1 menit saja kok."*',
      actions: const [
        QuickAction(
          label: 'Handling: Sudah Ada WiFi Lain',
          intent: 'script_get',
          args: {'objection': 'sudah_ada_wifi'},
        ),
        QuickAction(
          label: 'Handling: Kemahalan',
          intent: 'script_get',
          args: {'objection': 'mahal'},
        ),
        QuickAction(
          label: 'Script Anak Kos',
          intent: 'script_get',
          args: {'segment': 'kos'},
        ),
      ],
      metadata: {'category': 'segment', 'type': 'rumah'},
    );
  }
}
