import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

// Re-export the SP failure family so the settings cubit can switch on the
// revoke result without reaching into the SP feature's `domain/`.
export 'package:bb_mobile/features/sp/public/sp_facade.dart' show SpFailure;

/// Settings feature's own use case wrapping the Silent Payments facade, so the
/// `SettingsCubit` never calls `SpFacade` directly (AGENTS.md rule #4).
class RevokeSpWalletForSettingsUsecase {
  final SpFacade _spFacade;

  RevokeSpWalletForSettingsUsecase({required this._spFacade});

  Future<Result<void, SpFailure>> execute() => _spFacade.revoke();
}
