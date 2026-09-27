import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database_helper.dart';
import '../data/models/sa_record.dart';

class SaNotifier extends AsyncNotifier<List<SaRecord>> {
  @override
  Future<List<SaRecord>> build() async {
    return await DatabaseHelper.instance.getAllSaRecords();
  }

  Future<void> addSaRecord(SaRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.insertSaRecord(record);
      return await DatabaseHelper.instance.getAllSaRecords();
    });
  }

  Future<void> updateSaRecord(SaRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.updateSaRecord(record);
      return await DatabaseHelper.instance.getAllSaRecords();
    });
  }

  Future<void> deleteSaRecord(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.deleteSaRecord(id);
      return await DatabaseHelper.instance.getAllSaRecords();
    });
  }
}

final saProvider =
    AsyncNotifierProvider<SaNotifier, List<SaRecord>>(() => SaNotifier());
