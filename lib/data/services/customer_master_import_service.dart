import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml_events.dart';
import '../../auth/supabase_client.dart';

/// Exception ramah pengguna untuk proses baca/parse KMZ/KML.
class MasterImportException implements Exception {
  final String message;
  const MasterImportException(this.message);

  @override
  String toString() => message;
}

/// Exception ketika pengiriman batch RPC berhenti di tengah jalan.
class MasterImportBatchException implements Exception {
  final String message;
  final int savedCount;
  final int totalCount;
  final int insertedCount;
  final int updatedCount;
  final int rejectedCount;
  final Object? cause;

  const MasterImportBatchException({
    required this.message,
    required this.savedCount,
    required this.totalCount,
    this.insertedCount = 0,
    this.updatedCount = 0,
    this.rejectedCount = 0,
    this.cause,
  });

  @override
  String toString() => message;
}

/// Record pelanggan master yang HANYA memuat tepat 10 kolom whitelist.
/// Kolom sensitif (Serial Number Wifi/ONT/SIM CARD 1, WO ID, SO Number, Create/Close Time)
/// telah dibuang pada saat parsing di perangkat.
class MasterImportRecord {
  final String customerId;
  final String cityCode;
  final String? installDate;
  final String address;
  final String packageName;
  final double? latitude;
  final double? longitude;
  final String salesName;
  final String spvName;
  final String tscName;

  const MasterImportRecord({
    required this.customerId,
    required this.cityCode,
    required this.installDate,
    required this.address,
    required this.packageName,
    required this.latitude,
    required this.longitude,
    required this.salesName,
    required this.spvName,
    required this.tscName,
  });

  /// Mengonversi ke JSON snake_case sesuai parameter RPC `admin_import_customer_master`.
  /// TIDAK boleh ada field lain di luar 10 kunci whitelist ini.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'customer_id': customerId,
      'city_code': cityCode,
      'install_date': installDate,
      'address': address,
      'package_name': packageName,
      'latitude': latitude,
      'longitude': longitude,
      'sales_name': salesName,
      'spv_name': spvName,
      'tsc_name': tscName,
    };
  }
}

/// Statistik ringkasan hasil parse KML/KMZ (hanya angka agregat, tanpa data pribadi pelanggan).
class MasterImportStats {
  final int totalPlacemarks;
  final int cityMatched;
  final int validUnique;
  final int duplicates;
  final int missingCoords;
  final int missingInstallDate;
  final int missingSalesName;
  final int uniqueSales;
  final String? minInstallDate;
  final String? maxInstallDate;
  final Map<String, int> perTsc;
  final String batchId;

  const MasterImportStats({
    required this.totalPlacemarks,
    required this.cityMatched,
    required this.validUnique,
    required this.duplicates,
    required this.missingCoords,
    required this.missingInstallDate,
    required this.missingSalesName,
    required this.uniqueSales,
    required this.minInstallDate,
    required this.maxInstallDate,
    required this.perTsc,
    required this.batchId,
  });
}

/// Hasil gabungan daftar record unik dan statistik pratinjau.
class MasterImportParseResult {
  final List<MasterImportRecord> records;
  final MasterImportStats stats;

  const MasterImportParseResult({
    required this.records,
    required this.stats,
  });
}

/// Hasil akhir pengiriman seluruh batch ke RPC `admin_import_customer_master`.
class MasterImportResult {
  final int insertedCount;
  final int updatedCount;
  final int rejectedCount;
  final int totalSent;

  const MasterImportResult({
    required this.insertedCount,
    required this.updatedCount,
    required this.rejectedCount,
    required this.totalSent,
  });
}

/// Kunci tabel HTML deskripsi yang diizinkan (whitelist ketat).
const Set<String> kWhitelistHtmlKeys = <String>{
  'Customer ID',
  'City Code Homepass',
  'Install Date',
  'Homepass Address',
  'Product Name',
  'Latitude',
  'Longitude',
  'Sales Name',
  'SPV Name',
  'TSC Name',
};

/// Batas ukuran file KMZ/KML maksimum: 50 MB.
const int kMaxMasterImportFileBytes = 50 * 1024 * 1024;

/// Ukuran batch pengiriman RPC ke Supabase.
const int kMasterImportBatchSize = 500;

final RegExp _multiSpaceRe = RegExp(r'\s+');
final RegExp _dateIsoRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _htmlRowRe = RegExp(
  r'<tr[^>]*>\s*<t[dh][^>]*>(.*?)</t[dh]>\s*<t[dh][^>]*>(.*?)</t[dh]>\s*</tr>',
  caseSensitive: false,
  dotAll: true,
);
final RegExp _htmlTagStripRe = RegExp(r'<[^>]+>');

/// Trim, ubah spasi ganda menjadi satu spasi, dan UPPERCASE.
String normalizeMasterPersonName(String? value) {
  if (value == null || value.isEmpty) return '';
  final cleaned = value.trim().replaceAll(_multiSpaceRe, ' ');
  return cleaned.toUpperCase();
}

/// Ambil 10 karakter pertama format YYYY-MM-DD dan validasi tanggal kalender; kembalikan null bila tidak valid.
String? parseMasterInstallDate(String? value) {
  if (value == null || value.isEmpty) return null;
  final trimmed = value.trim();
  if (trimmed.length < 10) return null;
  final candidate = trimmed.substring(0, 10);
  if (!_dateIsoRe.hasMatch(candidate)) return null;
  final parts = candidate.split('-');
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final dt = DateTime.utc(year, month, day);
  if (dt.year != year || dt.month != month || dt.day != day) {
    return null;
  }
  return candidate;
}

/// Validasi pasangan koordinat dalam rentang lat -90..90, lon -180..180 (dan bukan 0).
/// Bila Latitude/Longitude dari tabel kosong/0/tidak valid, gunakan fallback dari `<coordinates>`.
(double?, double?) parseMasterCoordinates(
  String? latRaw,
  String? lonRaw, {
  double? fallbackLat,
  double? fallbackLon,
}) {
  (double, double)? toValidPair(Object? latVal, Object? lonVal) {
    if (latVal == null || lonVal == null) return null;
    final double? latF = latVal is num
        ? latVal.toDouble()
        : double.tryParse(latVal.toString().trim().replaceAll(',', '.'));
    final double? lonF = lonVal is num
        ? lonVal.toDouble()
        : double.tryParse(lonVal.toString().trim().replaceAll(',', '.'));
    if (latF == null || lonF == null) return null;
    if (!latF.isFinite || !lonF.isFinite) return null;
    if (latF == 0.0 || lonF == 0.0) return null;
    if (latF < -90.0 || latF > 90.0 || lonF < -180.0 || lonF > 180.0) {
      return null;
    }
    return (latF, lonF);
  }

  final primary = toValidPair(latRaw, lonRaw);
  if (primary != null) return (primary.$1, primary.$2);

  final fallback = toValidPair(fallbackLat, fallbackLon);
  if (fallback != null) return (fallback.$1, fallback.$2);

  return (null, null);
}

String _unescapeBasicHtml(String input) {
  if (!input.contains('&')) return input;
  return input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');
}

/// Ekstrak pasangan kunci-nilai dari tabel HTML `<tr><td>Kunci</td><td>Nilai</td></tr>`
/// dan langsung saring HANYA kunci yang masuk `kWhitelistHtmlKeys`.
Map<String, String> parseWhitelistedHtmlDescription(String descHtml) {
  if (descHtml.isEmpty) return const <String, String>{};
  final result = <String, String>{};
  for (final match in _htmlRowRe.allMatches(descHtml)) {
    final rawKey = (match.group(1) ?? '').replaceAll(_htmlTagStripRe, '');
    final rawVal = (match.group(2) ?? '').replaceAll(_htmlTagStripRe, '');
    final key = _unescapeBasicHtml(rawKey).trim();
    if (kWhitelistHtmlKeys.contains(key)) {
      final val = _unescapeBasicHtml(rawVal).trim();
      result[key] = val;
    }
  }
  return result;
}

(double?, double?) _parseCoordinateText(String coordText) {
  final trimmed = coordText.trim();
  if (trimmed.isEmpty) return (null, null);
  final firstToken = trimmed.split(_multiSpaceRe).first;
  final parts = firstToken.split(',');
  if (parts.length < 2) return (null, null);
  final lon = double.tryParse(parts[0].trim());
  final lat = double.tryParse(parts[1].trim());
  if (lat == null || lon == null) return (null, null);
  return (lat, lon);
}

/// Ekstrak bytes KML dari file KMZ (ZIP) atau kembalikan langsung bila sudah berupa KML.
Uint8List extractKmlFromKmz(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const MasterImportException('File kosong atau tidak dapat dibaca.');
  }
  if (bytes.length > kMaxMasterImportFileBytes) {
    throw const MasterImportException(
      'Ukuran file melebihi batas maksimum 50 MB.',
    );
  }

  // Periksa magic header ZIP ('PK' -> 0x50, 0x4B)
  final bool isZip =
      bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  if (isZip) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      throw const MasterImportException(
        'File KMZ rusak atau bukan arsip ZIP yang valid.',
      );
    }

    ArchiveFile? kmlFile;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name.toLowerCase().endsWith('doc.kml')) {
        kmlFile = file;
        break;
      }
    }
    if (kmlFile == null) {
      for (final file in archive.files) {
        if (!file.isFile) continue;
        if (file.name.toLowerCase().endsWith('.kml')) {
          kmlFile = file;
          break;
        }
      }
    }

    if (kmlFile == null) {
      throw const MasterImportException('File KMZ tidak berisi dokumen KML');
    }

    return kmlFile.content;
  }

  return bytes;
}

String _localTagName(String qualifiedName) {
  final colonIdx = qualifiedName.lastIndexOf(':');
  if (colonIdx >= 0 && colonIdx + 1 < qualifiedName.length) {
    return qualifiedName.substring(colonIdx + 1);
  }
  return qualifiedName;
}

/// Fungsi murni untuk mem-parse bytes KML menggunakan event streaming `parseEvents` dari paket `xml`.
/// Merupakan terjemahan setia dari `parse_kml_bytes` di `tools/import_customer_master.py`.
MasterImportParseResult parseKmlBytes(
  Uint8List kml, {
  String targetCity = 'KCLP',
  String? batchId,
}) {
  if (kml.isEmpty) {
    throw const MasterImportException('Dokumen KML kosong.');
  }

  final String targetCityNorm = targetCity.trim().toUpperCase();
  final String effectiveBatchId = (batchId != null && batchId.trim().isNotEmpty)
      ? batchId.trim()
      : DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());

  String xmlString;
  try {
    xmlString = utf8.decode(kml, allowMalformed: true);
  } catch (_) {
    throw const MasterImportException('Gagal mendekode teks KML (UTF-8).');
  }

  int totalPlacemarks = 0;
  int cityMatched = 0;
  int duplicateCount = 0;
  bool sawAnyElement = false;

  final dedupMap = <String, MasterImportRecord>{};

  bool inPlacemark = false;
  String? currentField; // 'description' atau 'coordinates'
  final StringBuffer descBuf = StringBuffer();
  final StringBuffer coordBuf = StringBuffer();

  try {
    for (final event in parseEvents(xmlString)) {
      if (event is XmlStartElementEvent) {
        sawAnyElement = true;
        final local = _localTagName(event.name).toLowerCase();
        if (local == 'placemark') {
          inPlacemark = true;
          currentField = null;
          descBuf.clear();
          coordBuf.clear();
          if (event.isSelfClosing) {
            totalPlacemarks++;
            inPlacemark = false;
          }
        } else if (inPlacemark) {
          if (local == 'description' && !event.isSelfClosing) {
            currentField = 'description';
          } else if (local == 'coordinates' && !event.isSelfClosing) {
            currentField = 'coordinates';
          }
        }
      } else if (event is XmlTextEvent) {
        if (inPlacemark && currentField != null) {
          if (currentField == 'description') {
            descBuf.write(event.value);
          } else if (currentField == 'coordinates') {
            coordBuf.write(event.value);
          }
        }
      } else if (event is XmlCDATAEvent) {
        if (inPlacemark && currentField != null) {
          if (currentField == 'description') {
            descBuf.write(event.value);
          } else if (currentField == 'coordinates') {
            coordBuf.write(event.value);
          }
        }
      } else if (event is XmlEndElementEvent) {
        final local = _localTagName(event.name).toLowerCase();
        if (inPlacemark &&
            (local == 'description' || local == 'coordinates')) {
          currentField = null;
        } else if (local == 'placemark' && inPlacemark) {
          inPlacemark = false;
          totalPlacemarks++;

          final whitelisted = parseWhitelistedHtmlDescription(
            descBuf.toString(),
          );
          final cityCode =
              (whitelisted['City Code Homepass'] ?? '').trim().toUpperCase();
          if (cityCode != targetCityNorm) {
            continue;
          }
          cityMatched++;

          final customerId = (whitelisted['Customer ID'] ?? '').trim();
          if (customerId.isEmpty) {
            continue;
          }

          final installDate = parseMasterInstallDate(
            whitelisted['Install Date'],
          );
          final (fbLat, fbLon) = _parseCoordinateText(coordBuf.toString());
          final (lat, lon) = parseMasterCoordinates(
            whitelisted['Latitude'],
            whitelisted['Longitude'],
            fallbackLat: fbLat,
            fallbackLon: fbLon,
          );

          final address = (whitelisted['Homepass Address'] ?? '')
              .trim()
              .replaceAll(_multiSpaceRe, ' ');
          final packageName = (whitelisted['Product Name'] ?? '')
              .trim()
              .replaceAll(_multiSpaceRe, ' ');

          final record = MasterImportRecord(
            customerId: customerId,
            cityCode: cityCode,
            installDate: installDate,
            address: address,
            packageName: packageName,
            latitude: lat,
            longitude: lon,
            salesName: normalizeMasterPersonName(whitelisted['Sales Name']),
            spvName: normalizeMasterPersonName(whitelisted['SPV Name']),
            tscName: normalizeMasterPersonName(whitelisted['TSC Name']),
          );

          final existing = dedupMap[customerId];
          if (existing != null) {
            duplicateCount++;
            final oldDate = existing.installDate ?? '';
            final newDate = record.installDate ?? '';
            if (newDate.compareTo(oldDate) >= 0) {
              dedupMap[customerId] = record;
            }
          } else {
            dedupMap[customerId] = record;
          }
        }
      }
    }
  } catch (e) {
    if (e is MasterImportException) rethrow;
    throw const MasterImportException(
      'File KML tidak valid atau format XML rusak.',
    );
  }

  if (!sawAnyElement) {
    throw const MasterImportException(
      'File bukan dokumen XML/KML yang valid.',
    );
  }

  final sortedRecords = dedupMap.values.toList()
    ..sort((a, b) => a.customerId.compareTo(b.customerId));

  int missingCoords = 0;
  int missingInstallDate = 0;
  int missingSalesName = 0;
  final uniqueSalesSet = <String>{};
  final validDates = <String>[];
  final perTsc = <String, int>{};

  for (final r in sortedRecords) {
    if (r.latitude == null || r.longitude == null) {
      missingCoords++;
    }
    if (r.installDate == null) {
      missingInstallDate++;
    } else {
      validDates.add(r.installDate!);
    }
    if (r.salesName.isEmpty) {
      missingSalesName++;
    } else {
      uniqueSalesSet.add(r.salesName);
    }
    final tscKey = r.tscName.isNotEmpty ? r.tscName : '(TANPA TSC)';
    perTsc[tscKey] = (perTsc[tscKey] ?? 0) + 1;
  }

  validDates.sort();
  final sortedPerTscKeys = perTsc.keys.toList()..sort();
  final orderedPerTsc = <String, int>{
    for (final k in sortedPerTscKeys) k: perTsc[k]!,
  };

  final stats = MasterImportStats(
    totalPlacemarks: totalPlacemarks,
    cityMatched: cityMatched,
    validUnique: sortedRecords.length,
    duplicates: duplicateCount,
    missingCoords: missingCoords,
    missingInstallDate: missingInstallDate,
    missingSalesName: missingSalesName,
    uniqueSales: uniqueSalesSet.length,
    minInstallDate: validDates.isNotEmpty ? validDates.first : null,
    maxInstallDate: validDates.isNotEmpty ? validDates.last : null,
    perTsc: orderedPerTsc,
    batchId: effectiveBatchId,
  );

  return MasterImportParseResult(
    records: sortedRecords,
    stats: stats,
  );
}

class _IsolateParseArgs {
  final Uint8List rawBytes;
  final String targetCity;
  final String? batchId;

  const _IsolateParseArgs({
    required this.rawBytes,
    required this.targetCity,
    this.batchId,
  });
}

MasterImportParseResult _extractAndParseInIsolate(_IsolateParseArgs args) {
  final kmlBytes = extractKmlFromKmz(args.rawBytes);
  return parseKmlBytes(
    kmlBytes,
    targetCity: args.targetCity,
    batchId: args.batchId,
  );
}

/// Gateway abstrak untuk pemanggilan RPC `admin_import_customer_master` agar mudah di-fake di unit test.
abstract class CustomerMasterImportRemoteGateway {
  Future<Map<String, dynamic>> callAdminImportCustomerMaster({
    required String batchId,
    required List<Map<String, dynamic>> rows,
  });
}

class SupabaseCustomerMasterImportGateway
    implements CustomerMasterImportRemoteGateway {
  final SupabaseClient? _injectedClient;
  const SupabaseCustomerMasterImportGateway([this._injectedClient]);

  SupabaseClient get _client => _injectedClient ?? AppSupabase.client;

  @override
  Future<Map<String, dynamic>> callAdminImportCustomerMaster({
    required String batchId,
    required List<Map<String, dynamic>> rows,
  }) async {
    final res = await _client
        .rpc(
          'admin_import_customer_master',
          params: {
            'p_batch_id': batchId,
            'p_rows': rows,
          },
        )
        .timeout(const Duration(seconds: 30));

    if (res is List && res.isNotEmpty && res.first is Map) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return const <String, dynamic>{
      'inserted_count': 0,
      'updated_count': 0,
      'rejected_count': 0,
    };
  }
}

/// Layanan Impor Master Pelanggan KCLP (Khusus SuperAdmin).
class CustomerMasterImportService {
  final CustomerMasterImportRemoteGateway _gateway;

  CustomerMasterImportService({
    SupabaseClient? supabaseClient,
    CustomerMasterImportRemoteGateway? remoteGateway,
  }) : _gateway =
           remoteGateway ?? SupabaseCustomerMasterImportGateway(supabaseClient);

  /// Menjalankan ekstraksi KMZ/KML dan parsing XML di background isolate (`compute`)
  /// agar UI tidak pernah macet.
  Future<MasterImportParseResult> parseFileBytesInIsolate(
    Uint8List fileBytes, {
    String targetCity = 'KCLP',
    String? batchId,
  }) async {
    if (fileBytes.length > kMaxMasterImportFileBytes) {
      throw const MasterImportException(
        'Ukuran file melebihi batas maksimum 50 MB.',
      );
    }
    return compute(
      _extractAndParseInIsolate,
      _IsolateParseArgs(
        rawBytes: fileBytes,
        targetCity: targetCity,
        batchId: batchId,
      ),
    );
  }

  /// Mengirim `records` per 500 baris ke RPC `admin_import_customer_master`.
  /// Bila satu batch gagal, langsung berhenti dan melempar `MasterImportBatchException`
  /// yang melaporkan "x dari y baris tersimpan" agar pengguna dapat mencoba lagi.
  Future<MasterImportResult> importRecords(
    List<MasterImportRecord> records,
    String batchId, {
    void Function(int done, int total)? onProgress,
  }) async {
    final int total = records.length;
    if (total == 0) {
      return const MasterImportResult(
        insertedCount: 0,
        updatedCount: 0,
        rejectedCount: 0,
        totalSent: 0,
      );
    }

    int savedSoFar = 0;
    int totalInserted = 0;
    int totalUpdated = 0;
    int totalRejected = 0;

    onProgress?.call(0, total);

    for (int offset = 0; offset < total; offset += kMasterImportBatchSize) {
      final int end = (offset + kMasterImportBatchSize < total)
          ? offset + kMasterImportBatchSize
          : total;
      final chunk = records.sublist(offset, end);
      final payload = chunk.map((r) => r.toJson()).toList(growable: false);

      try {
        final res = await _gateway.callAdminImportCustomerMaster(
          batchId: batchId,
          rows: payload,
        );
        final ins = (res['inserted_count'] as num?)?.toInt() ?? 0;
        final upd = (res['updated_count'] as num?)?.toInt() ?? 0;
        final rej = (res['rejected_count'] as num?)?.toInt() ?? 0;

        totalInserted += ins;
        totalUpdated += upd;
        totalRejected += rej;
        savedSoFar = end;
        onProgress?.call(savedSoFar, total);
      } catch (e) {
        final errLower = e.toString().toLowerCase();
        String reason = 'Gangguan koneksi atau server menolak permintaan.';
        if (errLower.contains('unauthorized') || errLower.contains('42501')) {
          reason = 'Akses ditolak: hanya Superadmin murni yang diizinkan mengimpor.';
        } else if (errLower.contains('socketexception') ||
            errLower.contains('failed host lookup') ||
            errLower.contains('timeout')) {
          reason = 'Koneksi internet terputus atau waktu tunggu habis.';
        }

        throw MasterImportBatchException(
          message:
              '$savedSoFar dari $total baris tersimpan. $reason Silakan tekan Coba Lagi.',
          savedCount: savedSoFar,
          totalCount: total,
          insertedCount: totalInserted,
          updatedCount: totalUpdated,
          rejectedCount: totalRejected,
          cause: e,
        );
      }
    }

    return MasterImportResult(
      insertedCount: totalInserted,
      updatedCount: totalUpdated,
      rejectedCount: totalRejected,
      totalSent: savedSoFar,
    );
  }
}
