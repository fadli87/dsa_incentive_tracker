import 'package:flutter/services.dart';
import '../models/cell_signal_info.dart';

/// Dart-side bridge ke Android native plugin untuk info seluler.
/// Menggunakan MethodChannel yang sama dengan G-Net Track clone
/// (channel: 'com.aura.network/telephony').
///
/// Kategori: SENSITIF — membutuhkan izin ACCESS_FINE_LOCATION + READ_PHONE_STATE.
/// Permission harus diminta sebelum memanggil method ini via PermissionService.
class TelephonyBridge {
  static const MethodChannel _channel = MethodChannel('com.aura.network/telephony');

  const TelephonyBridge();

  /// Mengambil daftar SIM slot yang aktif.
  /// Mengembalikan list kosong jika gagal (graceful fallback).
  Future<List<SimSlotInfo>> getSimSlots() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeMethod<List<dynamic>>('getSimSlots');
      if (rawList == null || rawList.isEmpty) {
        return const [
          SimSlotInfo(subscriptionId: 1, simSlotIndex: 0, displayName: 'SIM 1', carrierName: 'SIM 1', isActive: true),
          SimSlotInfo(subscriptionId: 2, simSlotIndex: 1, displayName: 'SIM 2', carrierName: 'SIM 2', isActive: false),
        ];
      }
      final list = rawList
          .map((item) => SimSlotInfo.fromMap(item as Map<dynamic, dynamic>))
          .where((s) => s.simSlotIndex == 0 || s.simSlotIndex == 1)
          .toList();
      if (list.isEmpty) {
        return const [
          SimSlotInfo(subscriptionId: 1, simSlotIndex: 0, displayName: 'SIM 1', carrierName: 'SIM 1', isActive: true),
          SimSlotInfo(subscriptionId: 2, simSlotIndex: 1, displayName: 'SIM 2', carrierName: 'SIM 2', isActive: false),
        ];
      }
      if (list.length == 1) {
        return [
          list.first,
          const SimSlotInfo(subscriptionId: 2, simSlotIndex: 1, displayName: 'SIM 2', carrierName: 'SIM 2', isActive: false),
        ];
      }
      return list.take(2).toList();
    } catch (_) {
      return const [
        SimSlotInfo(subscriptionId: 1, simSlotIndex: 0, displayName: 'SIM 1', carrierName: 'SIM 1', isActive: true),
        SimSlotInfo(subscriptionId: 2, simSlotIndex: 1, displayName: 'SIM 2', carrierName: 'SIM 2', isActive: false),
      ];
    }
  }

  /// Mengambil snapshot info cell saat ini untuk subscription tertentu atau slotIndex.
  /// Jika [subscriptionId] dan [slotIndex] null, pakai SIM default.
  /// Mengembalikan snapshot kosong dengan timestamp jika gagal.
  Future<TelephonySnapshot> getCellInfo({int? subscriptionId, int? slotIndex}) async {
    try {
      final Map<dynamic, dynamic>? rawMap =
          await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCellInfo',
        {
          'subscriptionId': ?subscriptionId,
          'slotIndex': ?slotIndex,
        },
      );
      return TelephonySnapshot.fromMap(rawMap);
    } catch (_) {
      return TelephonySnapshot(timestamp: DateTime.now());
    }
  }

  /// Mengambil snapshot statistik throughput data (rx/tx bytes).
  Future<NetworkTrafficSnapshot> getTrafficStats() async {
    try {
      final Map<dynamic, dynamic>? rawMap =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getTrafficStats');
      return NetworkTrafficSnapshot.fromMap(rawMap);
    } catch (_) {
      return const NetworkTrafficSnapshot();
    }
  }
}

/// Data class snapshot throughput bytes data.
class NetworkTrafficSnapshot {
  final int totalRxBytes;
  final int totalTxBytes;
  final int mobileRxBytes;
  final int mobileTxBytes;
  final int timestampMs;

  const NetworkTrafficSnapshot({
    this.totalRxBytes = 0,
    this.totalTxBytes = 0,
    this.mobileRxBytes = 0,
    this.mobileTxBytes = 0,
    this.timestampMs = 0,
  });

  factory NetworkTrafficSnapshot.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const NetworkTrafficSnapshot();
    return NetworkTrafficSnapshot(
      totalRxBytes: (map['totalRxBytes'] as num?)?.toInt() ?? 0,
      totalTxBytes: (map['totalTxBytes'] as num?)?.toInt() ?? 0,
      mobileRxBytes: (map['mobileRxBytes'] as num?)?.toInt() ?? 0,
      mobileTxBytes: (map['mobileTxBytes'] as num?)?.toInt() ?? 0,
      timestampMs: (map['timestampMs'] as num?)?.toInt() ?? 0,
    );
  }
}
