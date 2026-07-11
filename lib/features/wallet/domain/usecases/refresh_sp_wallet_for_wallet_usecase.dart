import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

// Re-export the public SP snapshot type + failure family so this feature's
// bloc/state can use them without reaching into the SP feature's `domain/`.
export 'package:bb_mobile/features/sp/public/sp_facade.dart'
    show SpWallet, SpFailure;

/// Wallet feature's own use case wrapping the Silent Payments facade, so the
/// `WalletBloc` never calls `SpFacade` directly (AGENTS.md rule #4).
class RefreshSpWalletForWalletUsecase {
  final SpFacade _spFacade;

  RefreshSpWalletForWalletUsecase({required this._spFacade});

  /// Reads a fresh snapshot from the live session without disposing it: the
  /// scanner updates the stores in place, so the snapshot is already current.
  /// `Ok(null)` when SP is not set up (gated/revoked); `Err` on failure so the
  /// bloc can leave its state intact and retry later.
  Future<Result<SpWallet?, SpFailure>> execute() => _spFacade.refresh();
}
