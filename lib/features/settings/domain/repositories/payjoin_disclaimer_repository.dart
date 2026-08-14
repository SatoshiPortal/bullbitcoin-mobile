import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

/// Whether the one-time payjoin disclaimer has already been shown.
///
/// The disclaimer is a privacy disclosure presented when the user turns payjoin
/// on (see PAYJOIN_FEATURES_PLAN D10/D11): it must interrupt exactly once, and
/// stay re-openable on demand from the payjoin settings screen. That single bit
/// is all this repository owns.
abstract interface class PayjoinDisclaimerRepository {
  @useResult
  Future<Result<bool, SettingsFailure>> hasBeenShown();

  @useResult
  Future<Result<void, SettingsFailure>> markShown();
}
