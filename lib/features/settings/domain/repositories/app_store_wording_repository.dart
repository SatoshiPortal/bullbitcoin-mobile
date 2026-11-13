import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

/// Development preference: show the App Store vocabulary on any platform.
///
/// A local flag of this device, not a user setting: it deliberately does not
/// live in the settings Drift table, like the payjoin disclaimer flag.
abstract interface class AppStoreWordingRepository {
  @useResult
  Future<Result<bool, SettingsFailure>> isForced();

  @useResult
  Future<Result<void, SettingsFailure>> setForced(bool forced);
}
