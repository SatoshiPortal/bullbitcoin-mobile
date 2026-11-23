import 'package:silent/silent.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';

/// Wallet feature's own use case wrapping the Silent Payments facade, so the
/// `WalletBloc` never calls `Silent` directly (AGENTS.md rule #4).
class CheckSpFeatureGateForWalletUsecase {
  final Silent _silent;

  CheckSpFeatureGateForWalletUsecase({required this._silent});

  Future<Result<bool, WalletFailure>> execute() async =>
      (await _silent.isFeatureEnabled()).mapErr(
        (_) => const WalletStorageFailure('Silent feature gate read failed'),
      );
}
