/// Normalizer teks offline untuk input pengguna dan query lapangan.
/// Menangani normalisasi huruf, pembersihan emoji/simbol, pemetaan slang/singkatan,
/// dan konversi kata bilangan Indonesia (0-100) menjadi angka digit.
class TextNormalizer {
  TextNormalizer._();

  static const Map<String, String> _slangMap = {
    'brp': 'berapa',
    'brapa': 'berapa',
    'gmn': 'bagaimana',
    'gimana': 'bagaimana',
    'gmana': 'bagaimana',
    'bgmn': 'bagaimana',
    'yg': 'yang',
    'yng': 'yang',
    'sdh': 'sudah',
    'udh': 'sudah',
    'udah': 'sudah',
    'dah': 'sudah',
    'utk': 'untuk',
    'untk': 'untuk',
    'bwt': 'untuk',
    'tdk': 'tidak',
    'tdak': 'tidak',
    'gk': 'tidak',
    'gak': 'tidak',
    'ga': 'tidak',
    'nggak': 'tidak',
    'ngga': 'tidak',
    'ndak': 'tidak',
    'enggak': 'tidak',
    'klo': 'kalau',
    'kalo': 'kalau',
    'klu': 'kalau',
    'kl': 'kalau',
    'sy': 'saya',
    'aku': 'saya',
    'km': 'kamu',
    'lu': 'kamu',
    'lo': 'kamu',
    'bisa': 'bisa',
    'bs': 'bisa',
    'dgn': 'dengan',
    'dg': 'dengan',
    'sm': 'sama',
    'smp': 'sampai',
    'sampe': 'sampai',
    'wifi': 'wifi',
    'wi-fi': 'wifi',
    'wifii': 'wifi',
    'speed': 'mbps',
    'kecepatan': 'mbps',
    'bandingin': 'bandingkan',
    'bedain': 'bandingkan',
    'bedanya': 'perbedaan',
    'beda': 'perbedaan',
    'kosan': 'kos',
    'kost': 'kos',
    'warung': 'warkop',
    'toko': 'umkm',
    'kantoran': 'kantor',
    'rsrp': 'rsrp',
    'sinr': 'sinr',
  };

  static final Map<String, int> _unitWords = {
    'nol': 0,
    'kosong': 0,
    'satu': 1,
    'dua': 2,
    'tiga': 3,
    'empat': 4,
    'lima': 5,
    'enam': 6,
    'tujuh': 7,
    'delapan': 8,
    'sembilan': 9,
    'sepuluh': 10,
    'sebelas': 11,
    'seratus': 100,
  };

  /// Normalisasi query input lengkap
  static String normalize(String input) {
    if (input.trim().isEmpty) return '';

    // 1. Lowercase dan bersihkan karakter aneh/emoji (hanya sisakan alfanumerik, spasi, titik, minus, koma, persen, tanda panah)
    String text = input.toLowerCase();

    // Ubah format uang singkatan: "250rb" -> "250 ribu", "1.2jt" -> "1.2 juta", "1,2jt" -> "1.2 juta", "250k" -> "250 ribu"
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(rb|k|ribu)\b'),
      (m) => '${m[1]?.replaceAll(',', '.')} ribu',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(jt|juta)\b'),
      (m) => '${m[1]?.replaceAll(',', '.')} juta',
    );

    // Hapus tanda baca berulang & simbol yang tidak perlu
    text = text.replaceAll(RegExp(r'[^\w\s.,+\-%/]'), ' ');

    // 2. Tokenize & ganti slang
    List<String> tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    for (int i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (_slangMap.containsKey(t)) {
        tokens[i] = _slangMap[t]!;
      }
    }

    // 3. Konversi kata bilangan Indonesia ke digit (0 - 100)
    tokens = _convertNumberWords(tokens);

    return tokens.join(' ').trim();
  }

  /// Memecah string yang sudah dinormalisasi menjadi list token kata bersih
  static List<String> tokenize(String normalized) {
    if (normalized.trim().isEmpty) return const [];
    return normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  /// Helper untuk mengubah urutan kata bilangan Indonesia menjadi angka
  static List<String> _convertNumberWords(List<String> tokens) {
    final List<String> result = [];
    int i = 0;

    while (i < tokens.length) {
      final t = tokens[i];

      // Cek apakah token saat ini adalah kata bilangan
      if (_unitWords.containsKey(t)) {
        int val = _unitWords[t]!;

        // Cek kombinasi "dua belas" .. "sembilan belas"
        if (i + 1 < tokens.length && tokens[i + 1] == 'belas' && val >= 2 && val <= 9) {
          val = 10 + val;
          i += 2;
          result.add(val.toString());
          continue;
        }

        // Cek kombinasi "dua puluh" .. "sembilan puluh"
        if (i + 1 < tokens.length && tokens[i + 1] == 'puluh' && val >= 2 && val <= 9) {
          val = val * 10;
          i += 2;
          // Cek satuan setelah puluh: misal "dua puluh lima" -> 25
          if (i < tokens.length && _unitWords.containsKey(tokens[i]) && _unitWords[tokens[i]]! < 10) {
            val += _unitWords[tokens[i]]!;
            i++;
          }
          result.add(val.toString());
          continue;
        }

        // Jika hanya angka dasar tunggal (mis. "lima", "sepuluh", "sebelas", "seratus")
        result.add(val.toString());
        i++;
      } else {
        result.add(t);
        i++;
      }
    }

    return result;
  }
}
