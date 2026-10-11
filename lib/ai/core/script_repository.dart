import 'dart:convert';
import 'package:intl/intl.dart';
import '../../core/catalog/package_catalog.dart';

/// Model representasi data skrip penjualan lapangan
class SalesScript {
  final String id;
  final String type; // objection | opening | closing
  final List<String> segment; // rumah, kos, warkop, umkm, kantor, any
  final String? objection; // mahal, sudah_ada_wifi, mikir, ribet, kontrak
  final String text;
  final List<String> requires;
  final DateTime? validUntil;

  const SalesScript({
    required this.id,
    required this.type,
    required this.segment,
    this.objection,
    required this.text,
    this.requires = const [],
    this.validUntil,
  });

  factory SalesScript.fromJson(Map<String, dynamic> json) {
    DateTime? validUntilDate;
    if (json['validUntil'] != null) {
      validUntilDate = DateTime.tryParse(json['validUntil'].toString());
    }

    return SalesScript(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'closing',
      segment: (json['segment'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const ['any'],
      objection: json['objection'] as String?,
      text: json['text'] as String? ?? '',
      requires: (json['requires'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      validUntil: validUntilDate,
    );
  }

  bool get isExpired {
    if (validUntil == null) return false;
    return DateTime.now().isAfter(validUntil!);
  }
}

/// Repository pengelola skrip komunikasi penjualan berbasis data
class ScriptRepository {
  ScriptRepository._();

  static List<SalesScript>? _cachedScripts;

  /// Default in-memory scripts sebagai cadangan sinkron dan seed
  static const String _defaultJson = '''
[
  {
    "id": "obj_mahal_rumah_01",
    "type": "objection",
    "segment": ["rumah", "any"],
    "objection": "mahal",
    "text": "Saya paham sekali pertimbangan Bapak/Ibu mengenai anggaran bulanan keluarga. Mari kita hitung bersama: jika anggota keluarga masing-masing membeli kuota HP bulanan 50rb dikali 4 orang, pengeluarannya sudah 200rb dan belum termasuk WiFi rumah. Dengan paket {paket} seharga {harga} per bulan berkecepatan {speed}, seluruh kebutuhan internet WiFi rumah unlimited dan kuota HP bersama sudah digabung menjadi satu tagihan hemat. Mau saya buatkan simulasi paket yang paling pas dengan budget keluarga?",
    "requires": ["paket", "harga", "speed"],
    "validUntil": null
  },
  {
    "id": "obj_sudah_ada_wifi_01",
    "type": "objection",
    "segment": ["rumah", "warkop", "any"],
    "objection": "sudah_ada_wifi",
    "text": "Bagus sekali kalau sudah terbiasa pakai WiFi di rumah Bapak/Ibu. Boleh saya tahu provider yang sekarang sering mengalami kendala lambat saat jam sibuk atau biaya langganannya naik berkala? XL Satu hadir dengan teknologi fiber optik terbaru berkecepatan {speed} seharga {harga} flat tanpa kenaikan mendadak, plus fasilitas gratis kuota HP bersama. Banyak tetangga di area sini yang beralih karena performa lebih stabil dan tagihan lebih terjangkau. Boleh saya cekkan titik jangkauan kabel ke rumah Bapak/Ibu sebentar?",
    "requires": ["harga", "speed"],
    "validUntil": null
  },
  {
    "id": "obj_mikir_01",
    "type": "objection",
    "segment": ["rumah", "kos", "warkop", "any"],
    "objection": "mikir",
    "text": "Tentu Bapak/Ibu, keputusan penting untuk kebutuhan keluarga memang perlu dipertimbangkan dengan matang. Sebagai referensi Bapak/Ibu, promo pendaftaran paket {paket} dengan tarif hemat {harga} per bulan ini memiliki kuota slot teknisi dan alokasi port ODP terbatas untuk wilayah RT/RW ini. Boleh saya tinggal brosur resmi dan catat nomor WhatsApp Bapak/Ibu agar bisa saya hubungi untuk update slot pemasangannya?",
    "requires": ["paket", "harga"],
    "validUntil": null
  },
  {
    "id": "obj_ribet_fwa_01",
    "type": "objection",
    "segment": ["rumah", "kos", "any"],
    "objection": "ribet",
    "text": "Bapak/Ibu tenang saja, jika tidak ingin proses penarikan kabel atau pengeboran dinding yang memakan waktu, kami memiliki solusi nirkabel {paket} seharga {harga} berkecepatan {speed}. Sistemnya Plug & Play nirkabel tanpa tarik kabel optik panjang. Teknisi resmi kami akan mengantarkan perangkat dan memastikan sinyal langsung aktif saat itu juga tanpa merusak estetika rumah.",
    "requires": ["paket", "harga", "speed"],
    "validUntil": null
  },
  {
    "id": "obj_kontrak_01",
    "type": "objection",
    "segment": ["rumah", "kos", "any"],
    "objection": "kontrak",
    "text": "Kekhawatiran yang sangat wajar Bapak/Ibu. Di XL Satu, seluruh ketentuan paket disampaikan secara transparan sejak awal tanpa ada biaya tersembunyi. Layanan internet kami fokus memberikan kepuasan koneksi terbaik dengan dukungan teknisi resmi dan call center 24 jam. Mau saya bantu verifikasi persyaratan registrasinya yang cukup dengan KTP?",
    "requires": [],
    "validUntil": null
  },
  {
    "id": "seg_kos_01",
    "type": "closing",
    "segment": ["kos"],
    "objection": null,
    "text": "Permisi Kak/Ibu pemilik kos, mau tanya untuk koneksi internet di kosan sering melambat pas jam malam saat semua penghuni online bersamaan? XL Satu punya solusi internet praktis Plug & Play berkecepatan {speed} dengan paket {paket} seharga {harga} yang bisa dinikmati bersama dengan kuota besar. Sangat pas untuk tugas kuliah, streaming, maupun gaming bersama teman kos tanpa putus-putus. Mau saya bantu cekkan paket yang paling pas untuk kosan ini?",
    "requires": ["paket", "harga", "speed"],
    "validUntil": null
  },
  {
    "id": "seg_warkop_01",
    "type": "closing",
    "segment": ["warkop", "umkm"],
    "objection": null,
    "text": "Selamat siang Bapak/Ibu, izin numpang info solusi internet untuk menaikkan kenyamanan pengunjung warung/toko Anda. Koneksi WiFi yang cepat dan stabil terbukti membuat pelanggan betah nongkrong dan berbelanja lebih lama. XL Satu menawarkan paket {paket} berkecepatan {speed} dengan biaya bulanan flat {harga} yang sangat bersahabat untuk operasional usaha, plus sistem kasir dan CCTV tetap online lancar. Boleh saya cekkan jaringan di ruko/lokasi usaha Bapak/Ibu?",
    "requires": ["paket", "harga", "speed"],
    "validUntil": null
  },
  {
    "id": "seg_rumah_01",
    "type": "closing",
    "segment": ["rumah"],
    "objection": null,
    "text": "Selamat pagi/siang Bapak/Ibu, perkenalkan saya dari tim resmi XL Satu FIBER. Kami sedang melakukan pendataan jaringan baru di area lingkungan perumahan ini. Saat ini kami menyediakan paket bundling internet rumah unlimited {speed} mulai dari {harga}/bulan dengan paket {paket} sudah termasuk gratis kuota HP bersama sekeluarga. Boleh saya bantu cek apakah rumah Bapak/Ibu sudah terlewati tiang ODP fiber terdekat?",
    "requires": ["paket", "harga", "speed"],
    "validUntil": null
  }
]
''';

  /// Memuat list skrip (di-cache di memori)
  static List<SalesScript> getAllScripts({String? jsonSource}) {
    if (jsonSource != null) {
      final List<dynamic> list = jsonDecode(jsonSource) as List<dynamic>;
      return list.map((e) => SalesScript.fromJson(e as Map<String, dynamic>)).toList();
    }

    if (_cachedScripts == null) {
      final List<dynamic> list = jsonDecode(_defaultJson) as List<dynamic>;
      _cachedScripts = list.map((e) => SalesScript.fromJson(e as Map<String, dynamic>)).toList();
    }
    return _cachedScripts!;
  }

  /// Menemukan skrip yang cocok berdasarkan objection atau segmen
  static SalesScript? findScript({
    String? objection,
    String? segment,
    String? type,
  }) {
    final scripts = getAllScripts().where((s) => !s.isExpired).toList();

    if (objection != null && objection.isNotEmpty) {
      final matches = scripts.where((s) => s.objection == objection).toList();
      if (segment != null) {
        final exactSegment = matches.where((s) => s.segment.contains(segment)).toList();
        if (exactSegment.isNotEmpty) return exactSegment.first;
      }
      if (matches.isNotEmpty) return matches.first;
    }

    if (segment != null && segment.isNotEmpty) {
      final matches = scripts.where((s) => s.segment.contains(segment)).toList();
      if (matches.isNotEmpty) return matches.first;
    }

    if (type != null && type.isNotEmpty) {
      final matches = scripts.where((s) => s.type == type).toList();
      if (matches.isNotEmpty) return matches.first;
    }

    return scripts.isNotEmpty ? scripts.first : null;
  }

  /// Memformat teks skrip dengan data katalog nyata.
  /// Jika ada placeholder yang tidak dapat diisi, kalimat yang mengandung placeholder tersebut akan dibuang.
  static String formatScript(
    String rawText, {
    CatalogPackage? package,
    Map<String, String>? customPlaceholders,
  }) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Kumpulkan nilai placeholder yang tersedia
    final Map<String, String> values = {};
    if (package != null) {
      values['paket'] = package.title;
      values['harga'] = currencyFormatter.format(package.price);
      values['speed'] = '${package.speedMbps} Mbps';
      values['instalasi'] = package.installation;
      values['promo'] = package.speedUpgrade != null ? 'Promo ${package.speedUpgrade}' : package.tag;
    }

    if (customPlaceholders != null) {
      values.addAll(customPlaceholders);
    }

    // Pisahkan teks menjadi kalimat-kalimat
    final sentences = rawText.split(RegExp(r'(?<=[.?!])\s+'));
    final List<String> validSentences = [];

    for (var sentence in sentences) {
      var formatted = sentence;
      bool hasUnresolvedPlaceholder = false;

      // Cari semua placeholder {name}
      final matches = RegExp(r'\{([a-zA-Z0-9_]+)\}').allMatches(sentence);
      for (final match in matches) {
        final key = match.group(1)!;
        if (values.containsKey(key) && values[key]!.isNotEmpty) {
          formatted = formatted.replaceAll('{$key}', values[key]!);
        } else {
          hasUnresolvedPlaceholder = true;
          break;
        }
      }

      // Jika tidak ada placeholder yang tak terisi, simpan kalimatnya
      if (!hasUnresolvedPlaceholder) {
        validSentences.add(formatted);
      }
    }

    return validSentences.join(' ').trim();
  }
}
