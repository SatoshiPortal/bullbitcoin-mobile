import 'package:primitives/primitives.dart';
import 'package:silent/silent.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';

/// Settings feature's own use case wrapping the Silent Payments facade, so the
/// `SettingsCubit` never calls `Silent` directly (AGENTS.md rule #4).
class CheckSpWalletSetupForSettingsUsecase {
  final Silent _silent;

  CheckSpWalletSetupForSettingsUsecase({required this._silent});

  Future<Result<bool, SettingsFailure>> execute() async =>
      (await _silent.isSetUp()).mapErr(
        (_) => const SettingsStorageFailure('Silent setup read failed'),
      );
}
