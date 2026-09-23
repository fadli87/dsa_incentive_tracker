import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database_helper.dart';
import '../data/models/user_profile.dart';

class UserInfoNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    return await DatabaseHelper.instance.getUserProfile();
  }

  Future<void> updateProfile({
    required String name,
    required String salesCode,
    String branch = 'XL SATU CILACAP',
    String tsc = 'TSC PIPIN',
  }) async {
    final profile = UserProfile(
      name: name.trim(),
      salesCode: salesCode.trim(),
      branch: branch.trim(),
      tsc: tsc.trim(),
    );

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.saveUserProfile(profile);
      return profile;
    });
  }
}

final userInfoProvider =
    AsyncNotifierProvider<UserInfoNotifier, UserProfile>(() => UserInfoNotifier());
