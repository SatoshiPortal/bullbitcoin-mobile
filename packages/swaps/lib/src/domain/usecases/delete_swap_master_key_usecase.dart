import 'package:swaps/src/data/boltz_swap_repository.dart';

/// Deletes the derived swap master key (and its index counter) for the
/// default bitcoin wallet. The next swap or restore re-derives it.
class DeleteSwapMasterKeyUsecase {
  final BoltzSwapRepository _swapRepository;

  DeleteSwapMasterKeyUsecase({required this._swapRepository});

  Future<void> execute() async {
    final fingerprint = await _swapRepository.defaultBitcoinFingerprint();
    if (fingerprint == null || fingerprint.isEmpty) return;
    await _swapRepository.deleteSwapMasterKey(walletFingerprint: fingerprint);
  }
}
