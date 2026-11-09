import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_providers.dart';
import '../data/local/database_helper.dart';
import '../data/services/backup_sync_service.dart';
import 'history_provider.dart';
import 'sa_provider.dart';

final backupSyncServiceProvider = Provider<BackupSyncService>((ref) {
  return BackupSyncService();
});

final backupConsentStatusProvider = FutureProvider<BackupConsentStatus>((ref) async {
  return ref.watch(backupSyncServiceProvider).getConsentStatus();
});

final backupLastSyncAtProvider = FutureProvider<DateTime?>((ref) async {
  return ref.watch(backupSyncServiceProvider).getLastSyncAt();
});

final saPendingSyncCountProvider = FutureProvider<int>((ref) async {
  ref.watch(saProvider);
  final pending = await DatabaseHelper.instance.getPendingSaRecords();
  return pending.length;
});

final historyPendingSyncCountProvider = FutureProvider<int>((ref) async {
  ref.watch(historyProvider);
  final pending = await DatabaseHelper.instance.getPendingIncentiveRecords();
  return pending.length;
});

final backupPendingCountProvider = FutureProvider<int>((ref) async {
  ref.watch(saProvider);
  ref.watch(historyProvider);
  return DatabaseHelper.instance.countPendingBackupItems();
});

/// Menjalankan sinkronisasi cadangan (`syncAll`) lalu me-refresh state provider terkait.
Future<BackupSyncResult> runBackupSyncAndRefresh(WidgetRef ref) async {
  final isApproved = ref.read(accessGateProvider) == GateState.approved;
  final service = ref.read(backupSyncServiceProvider);
  final res = await service.syncAll(isMemberApproved: isApproved);
  ref.invalidate(saProvider);
  ref.invalidate(historyProvider);
  ref.invalidate(saPendingSyncCountProvider);
  ref.invalidate(historyPendingSyncCountProvider);
  ref.invalidate(backupPendingCountProvider);
  ref.invalidate(backupLastSyncAtProvider);
  ref.invalidate(backupConsentStatusProvider);
  return res;
}

/// Menampilkan dialog persetujuan sekali ("Cadangkan data ke server tim?")
/// apabila terdapat data lokal dan status persetujuan masih `unset` (atau `declined` >= 7 hari).
Future<void> showBackupConsentDialogIfNeeded(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(backupSyncServiceProvider);
  if (!service.isConfigured) return;
  final saRows = await DatabaseHelper.instance.getAllSaRecords();
  final incRows = await DatabaseHelper.instance.getAllRecords();
  final hasLocalData = saRows.isNotEmpty || incRows.isNotEmpty;

  final shouldPrompt = await service.shouldPromptConsent(
    hasLocalData: hasLocalData,
  );
  if (!shouldPrompt || !context.mounted) return;

  final approved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      key: const Key('backup_consent_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: Color(0xFF002B66)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cadangkan data ke server tim?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: const Text(
        'Data pelanggan (termasuk nama, nomor HP, alamat) dan riwayat insentif disimpan terenkripsi di server tim.\n\n'
        '• Sales hanya melihat datanya sendiri.\n'
        '• SPV dan TSC dapat melihat data pelanggan (hanya baca).\n'
        '• Hanya Superadmin yang dapat melihat nominal insentif.',
        style: TextStyle(fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          key: const Key('backup_consent_later_btn'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Nanti'),
        ),
        ElevatedButton.icon(
          key: const Key('backup_consent_grant_btn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF002B66),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.sync, size: 16),
          label: const Text('Sinkronkan'),
        ),
      ],
    ),
  );

  if (approved == true) {
    await service.setConsentGranted();
    ref.invalidate(backupConsentStatusProvider);
    await runBackupSyncAndRefresh(ref);
  } else if (approved == false) {
    await service.setConsentDeclined();
    ref.invalidate(backupConsentStatusProvider);
  }
}
