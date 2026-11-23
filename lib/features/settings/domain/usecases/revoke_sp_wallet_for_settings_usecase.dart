import 'package:primitives/primitives.dart';
import 'package:silent/silent.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';

/// Settings feature's own use case wrapping the Silent Payments facade, so the
/// `SettingsCubit` never calls `Silent` directly (AGENTS.md rule #4).
class RevokeSpWalletForSettingsUsecase {
  final Silent _silent;

  RevokeSpWalletForSettingsUsecase({required this._silent});

  Future<Result<void, SettingsFailure>> execute() async =>
      (await _silent.revoke()).mapErr(
        (_) => const SettingsStorageFailure('Silent revoke failed'),
      );
}
