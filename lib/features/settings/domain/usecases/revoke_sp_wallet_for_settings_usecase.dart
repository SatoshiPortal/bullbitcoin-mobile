import 'package:bb_mobile/features/sp/public/sp_facade.dart';

/// Settings feature's own use case wrapping the Silent Payments facade, so the
/// `SettingsCubit` never calls `SpFacade` directly (AGENTS.md rule #4).
class RevokeSpWalletForSettingsUsecase {
  final SpFacade _spFacade;

  RevokeSpWalletForSettingsUsecase({required this._spFacade});

  Future<void> execute() => _spFacade.revoke();
}
