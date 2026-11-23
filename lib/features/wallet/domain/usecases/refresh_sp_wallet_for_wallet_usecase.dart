import 'package:primitives/primitives.dart';
import 'package:silent/silent.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';

/// Wallet feature's own use case wrapping the Silent Payments facade, so the
/// `WalletBloc` never calls `Silent` directly (AGENTS.md rule #4).
class RefreshSpWalletForWalletUsecase {
  final Silent _silent;

  RefreshSpWalletForWalletUsecase({required this._silent});

  /// Reads a fresh snapshot from the live session without disposing it: the
  /// scanner updates the stores in place, so the snapshot is already current.
  /// `Ok(null)` when SP is not set up (gated/revoked); `Err` on failure so the
  /// bloc can leave its state intact and retry later.
  Future<Result<SilentWallet?, WalletFailure>> execute() async =>
      (await _silent.refresh()).mapErr(
        (_) => const WalletStorageFailure('Silent wallet read failed'),
      );
}
