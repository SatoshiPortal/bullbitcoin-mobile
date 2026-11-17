import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/boltz_swaps.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';

/// The rescue key's words for a wallet, for display in the seed viewer.
class GetSwapMnemonicUsecase {
  final BoltzSwaps _boltz;

  const GetSwapMnemonicUsecase(this._boltz);

  Future<Result<String?, SwapsFailure>> execute({
    required String walletFingerprint,
  }) => _boltz.masterKeyMnemonic(walletFingerprint: walletFingerprint);
}
