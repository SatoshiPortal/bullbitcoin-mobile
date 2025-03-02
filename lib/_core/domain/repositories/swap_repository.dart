import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';

abstract class SwapRepository {
  Future<Swap> createLightningToLiquidSwap({
    required String mnemonic,
    required String walletId,
    required BigInt amountSat,
    required Environment environment,
    required String electrumUrl,
  });

  Future<String> claimLightningToLiquidSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });

  Future<Swap> createLightningToBitcoinSwap({
    required String mnemonic,
    required String walletId,
    required BigInt amountSat,
    required Environment environment,
    required String electrumUrl,
  });

  Future<String> claimLightningToBitcoinSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
    required bool tryCooperate,
    required bool broadcastViaBoltz,
  });
}
