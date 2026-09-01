import 'package:bb_mobile/features/sp/public/sp_facade.dart';

/// Wallet feature's own use case wrapping the Silent Payments facade, so the
/// `WalletBloc` never calls `SpFacade` directly (AGENTS.md rule #4).
class CheckSpFeatureGateForWalletUsecase {
  final SpFacade _spFacade;

  CheckSpFeatureGateForWalletUsecase({required this._spFacade});

  Future<bool> execute() => _spFacade.isFeatureEnabled();
}
