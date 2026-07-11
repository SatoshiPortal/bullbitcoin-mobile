import 'package:bb_mobile/features/sp/public/sp_facade.dart';

// Re-export the public SP snapshot type so this feature's bloc/state can use
// it without reaching into the SP feature's `domain/`.
export 'package:bb_mobile/features/sp/public/sp_facade.dart' show SpWallet;

/// Wallet feature's own use case wrapping the Silent Payments facade, so the
/// `WalletBloc` never calls `SpFacade` directly (AGENTS.md rule #4).
class RefreshSpWalletForWalletUsecase {
  final SpFacade _spFacade;

  RefreshSpWalletForWalletUsecase({required this._spFacade});

  /// Reads a fresh snapshot from the live session without disposing it: the
  /// scanner updates the stores in place, so the snapshot is already current.
  /// Returns null when SP is not set up (gated/revoked). Rethrows on dispose
  /// timeout so the bloc can leave its state intact and retry later.
  Future<SpWallet?> execute() => _spFacade.refresh();
}
