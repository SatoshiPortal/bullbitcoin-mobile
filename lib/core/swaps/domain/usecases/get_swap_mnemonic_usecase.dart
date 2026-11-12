import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';

/// The swap mnemonic, read at the moment it is drawn.
///
/// Its own usecase, and deliberately not part of [SwapMasterKeyInfo]: the
/// words must not sit in cubit state for the life of a screen. The caller is
/// a `FutureBuilder` inside the card that renders them, which is the closest
/// the app can get to `MnemonicView` for a credential that belongs to
/// `swaps` rather than to `secrets`.
class GetSwapMnemonicUsecase {
  final BoltzSwapRepository _swapRepository;

  GetSwapMnemonicUsecase({required this._swapRepository});

  Future<String?> execute({required String walletFingerprint}) =>
      _swapRepository.getSwapMnemonic(walletFingerprint: walletFingerprint);
}
