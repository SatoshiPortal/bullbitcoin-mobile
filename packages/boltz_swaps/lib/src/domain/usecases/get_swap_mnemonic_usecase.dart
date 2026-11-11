import 'package:boltz_swaps/src/data/boltz_swap_repository.dart';

/// The swap mnemonic, read at the moment it is drawn. Deliberately not part
/// of `SwapMasterKeyInfo`: the words must not sit in screen state for the
/// life of a screen.
class GetSwapMnemonicUsecase {
  final BoltzSwapRepository _swapRepository;

  GetSwapMnemonicUsecase({required this._swapRepository});

  Future<String?> execute({required String walletFingerprint}) =>
      _swapRepository.getSwapMnemonic(walletFingerprint: walletFingerprint);
}
