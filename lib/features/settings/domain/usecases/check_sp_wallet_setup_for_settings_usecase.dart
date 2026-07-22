import 'package:bb_mobile/features/sp/public/sp_facade.dart';

/// Settings feature's own use case wrapping the Silent Payments facade, so the
/// `SettingsCubit` never calls `SpFacade` directly (AGENTS.md rule #4).
class CheckSpWalletSetupForSettingsUsecase {
  final SpFacade _spFacade;

  CheckSpWalletSetupForSettingsUsecase({required this._spFacade});

  Future<bool> execute() => _spFacade.isSetUp();
}
