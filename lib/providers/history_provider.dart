import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_providers.dart';
import '../data/local/database_helper.dart';
import '../data/models/incentive_record.dart';
import 'backup_provider.dart';

class HistoryNotifier extends AsyncNotifier<List<IncentiveRecord>> {
  @override
  Future<List<IncentiveRecord>> build() async {
    return await DatabaseHelper.instance.getAllRecords();
  }

  void _triggerBackgroundBackup() {
    final isApproved =
        ref.read(accessGateProvider).valueOrNull == GateState.approved;
    unawaited(
      ref
          .read(backupSyncServiceProvider)
          .pushPending(isMemberApproved: isApproved)
          .then((_) {
            ref.invalidate(historyPendingSyncCountProvider);
            ref.invalidate(backupPendingCountProvider);
            ref.invalidate(backupLastSyncAtProvider);
          }),
    );
  }

  Future<void> addRecord(IncentiveRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.insertRecord(record);
      return await DatabaseHelper.instance.getAllRecords();
    });
    _triggerBackgroundBackup();
  }

  Future<void> deleteRecord(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.deleteRecord(id);
      return await DatabaseHelper.instance.getAllRecords();
    });
    _triggerBackgroundBackup();
  }

  Future<void> updateRecord(IncentiveRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.updateRecord(record);
      return await DatabaseHelper.instance.getAllRecords();
    });
    _triggerBackgroundBackup();
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<IncentiveRecord>>(() => HistoryNotifier());
