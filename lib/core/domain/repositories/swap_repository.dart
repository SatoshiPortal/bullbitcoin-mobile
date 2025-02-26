import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/swap.dart';

abstract class SwapRepository {
  Future<Swap> createLightningToLiquidSwap({
    required String liquidAddress,
    required BigInt amountSat,
    Environment environment,
  });

  Future<Swap> createLightningToBitcoinSwap({
    required String bitcoinAddress,
    required BigInt amountSat,
    Environment environment,
  });
}
