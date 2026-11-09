import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_providers.dart';
import '../data/local/database_helper.dart';
import '../data/models/sa_record.dart';
import 'backup_provider.dart';

class SaNotifier extends AsyncNotifier<List<SaRecord>> {
  @override
  Future<List<SaRecord>> build() async {
    return await DatabaseHelper.instance.getAllSaRecords();
  }

  void _triggerBackgroundBackup() {
    final isApproved =
        ref.read(accessGateProvider) == GateState.approved;
    unawaited(
      ref
          .read(backupSyncServiceProvider)
          .pushPending(isMemberApproved: isApproved)
          .then((_) {
            ref.invalidate(saPendingSyncCountProvider);
            ref.invalidate(backupPendingCountProvider);
            ref.invalidate(backupLastSyncAtProvider);
          }),
    );
  }

  Future<void> addSaRecord(SaRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.insertSaRecord(record);
      return await DatabaseHelper.instance.getAllSaRecords();
    });
    _triggerBackgroundBackup();
  }

  Future<void> updateSaRecord(SaRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.updateSaRecord(record);
      return await DatabaseHelper.instance.getAllSaRecords();
    });
    _triggerBackgroundBackup();
  }

  Future<void> deleteSaRecord(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.deleteSaRecord(id);
      return await DatabaseHelper.instance.getAllSaRecords();
    });
    _triggerBackgroundBackup();
  }
}

final saProvider =
    AsyncNotifierProvider<SaNotifier, List<SaRecord>>(() => SaNotifier());
