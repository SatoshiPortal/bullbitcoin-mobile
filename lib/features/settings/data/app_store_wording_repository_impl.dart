import 'package:bb_mobile/features/settings/domain/repositories/app_store_wording_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SharedPreferences]-backed implementation: the only file that knows the pref
/// key name. One boolean, so no separate datasource (AGENTS.md rule #6).
class AppStoreWordingRepositoryImpl implements AppStoreWordingRepository {
  static const _forcedKey = 'dev_force_app_store_wording';

  @override
  Future<Result<bool, SettingsFailure>> isForced() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok(prefs.getBool(_forcedKey) ?? false);
    } catch (e, st) {
      log.warning(
        'Failed to read the App Store wording flag: ${e.runtimeType}',
        trace: st,
      );
      return const Err(SettingsStorageFailure());
    }
  }

  @override
  Future<Result<void, SettingsFailure>> setForced(bool forced) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(_forcedKey, forced)) {
        return const Err(
          SettingsStorageFailure('Failed to persist the wording flag'),
        );
      }
      return const Ok(null);
    } catch (e, st) {
      log.warning(
        'Failed to persist the App Store wording flag: ${e.runtimeType}',
        trace: st,
      );
      return const Err(SettingsStorageFailure());
    }
  }
}
