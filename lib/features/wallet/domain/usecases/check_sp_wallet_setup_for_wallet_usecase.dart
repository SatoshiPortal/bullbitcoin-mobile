import 'package:primitives/primitives.dart';
import 'package:silent/silent.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';

/// Wallet feature's own use case wrapping the Silent Payments facade, so the
/// `WalletBloc` never calls `Silent` directly (AGENTS.md rule #4).
class CheckSpWalletSetupForWalletUsecase {
  final Silent _silent;

  CheckSpWalletSetupForWalletUsecase({required this._silent});

  Future<Result<bool, WalletFailure>> execute() async =>
      (await _silent.isSetUp()).mapErr(
        (_) => const WalletStorageFailure('Silent setup read failed'),
      );
}
