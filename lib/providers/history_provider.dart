import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database_helper.dart';
import '../data/models/incentive_record.dart';

class HistoryNotifier extends AsyncNotifier<List<IncentiveRecord>> {
  @override
  Future<List<IncentiveRecord>> build() async {
    return await DatabaseHelper.instance.getAllRecords();
  }

  Future<void> addRecord(IncentiveRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.insertRecord(record);
      return await DatabaseHelper.instance.getAllRecords();
    });
  }

  Future<void> deleteRecord(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.deleteRecord(id);
      return await DatabaseHelper.instance.getAllRecords();
    });
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<IncentiveRecord>>(() => HistoryNotifier());
