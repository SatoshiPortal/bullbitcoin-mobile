import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/swap.dart';

abstract class SwapRepository {
  Future<Swap> createLightningToLiquidSwap({
    required String mnemonic,
    required BigInt index,
    required String walletId,
    required BigInt amountSat,
    required Environment environment,
    required String electrumUrl,
  });

  Future<Swap> createLightningToBitcoinSwap({
    required String mnemonic,
    required BigInt index,
    required String walletId,
    required BigInt amountSat,
    required Environment environment,
    required String electrumUrl,
  });

  Future<BigInt> getNextBestIndex(String walletId);
}
