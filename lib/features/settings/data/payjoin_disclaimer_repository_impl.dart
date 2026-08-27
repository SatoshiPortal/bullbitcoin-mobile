import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/repositories/payjoin_disclaimer_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SharedPreferences]-backed implementation: the only file that knows the pref
/// key name.
///
/// No separate datasource on purpose — one boolean flag is trivial CRUD, and a
/// datasource forwarding two calls to a repository forwarding them back is the
/// noise AGENTS.md rule #6 warns about. The flag is presentation state (has the
/// user been interrupted yet), so it deliberately does NOT live in the settings
/// Drift table alongside the payjoin settings themselves.
class PayjoinDisclaimerRepositoryImpl implements PayjoinDisclaimerRepository {
  static const _shownKey = 'payjoin_disclaimer_shown';

  @override
  Future<Result<bool, SettingsFailure>> hasBeenShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok(prefs.getBool(_shownKey) ?? false);
    } catch (e) {
      log.warning('Failed to read the Payjoin disclaimer flag: $e');
      return Err(SettingsStorageFailure(e.toString()));
    }
  }

  @override
  Future<Result<void, SettingsFailure>> markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setBool(_shownKey, true);
      if (!saved) {
        return const Err(
          SettingsStorageFailure('Failed to persist the disclaimer flag'),
        );
      }
      return const Ok(null);
    } catch (e) {
      log.warning('Failed to persist the Payjoin disclaimer flag: $e');
      return Err(SettingsStorageFailure(e.toString()));
    }
  }
}
