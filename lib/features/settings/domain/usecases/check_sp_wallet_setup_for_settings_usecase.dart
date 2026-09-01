import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

export 'package:bb_mobile/features/sp/public/sp_facade.dart' show SpFailure;

/// Settings feature's own use case wrapping the Silent Payments facade, so the
/// `SettingsCubit` never calls `SpFacade` directly (AGENTS.md rule #4).
class CheckSpWalletSetupForSettingsUsecase {
  final SpFacade _spFacade;

  CheckSpWalletSetupForSettingsUsecase({required this._spFacade});

  Future<Result<bool, SpFailure>> execute() => _spFacade.isSetUp();
}
