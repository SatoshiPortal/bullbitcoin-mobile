import 'package:boltz_swaps/src/data/boltz_swap_repository.dart';
import 'package:boltz_swaps/src/domain/entities/swap_master_key_info.dart';

/// Reads the swap master key (the "swap mnemonic") for the default bitcoin
/// wallet, for display in the seed viewer. Null when no default bitcoin
/// wallet exists or no swap key has been derived yet.
class GetSwapMasterKeyUsecase {
  final BoltzSwapRepository _swapRepository;

  GetSwapMasterKeyUsecase({required this._swapRepository});

  Future<SwapMasterKeyInfo?> execute() async {
    final fingerprint = await _swapRepository.defaultBitcoinFingerprint();
    if (fingerprint == null || fingerprint.isEmpty) return null;
    return _swapRepository.getSwapMasterKeyInfo(walletFingerprint: fingerprint);
  }
}
