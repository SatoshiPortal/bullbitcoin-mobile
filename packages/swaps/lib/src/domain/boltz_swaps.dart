import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/entities/swap_master_key_info.dart';

/// Where a chain swap's claim lands: one of our wallets, or an external
/// address on the destination chain.
sealed class ChainSwapDestination {
  const ChainSwapDestination();
}

final class ToWallet extends ChainSwapDestination {
  final String walletId;

  const ToWallet(this.walletId);
}

final class ToAddress extends ChainSwapDestination {
  final String address;

  const ToAddress(this.address);
}

/// The pairs Boltz serves. Each create checks the amount against Boltz's
/// limits and verifies the wallet is on the pair's chain before anything
/// is created.
abstract interface class BoltzSwaps {
  Future<Result<(SwapLimits, SwapFees), SwapsFailure>> limitsAndFees(
    SwapType type,
  );

  /// Pays [invoice] from a Bitcoin wallet. Reuses the swap already created
  /// for the same invoice while nothing was locked into it.
  Future<Result<LnSendSwap, SwapsFailure>> createBitcoinToLightningSwap({
    required String walletId,
    required String invoice,
  });

  /// Pays [invoice] from a Liquid wallet. Reuses the swap already created
  /// for the same invoice while nothing was locked into it.
  Future<Result<LnSendSwap, SwapsFailure>> createLiquidToLightningSwap({
    required String walletId,
    required String invoice,
  });

  Future<Result<LnReceiveSwap, SwapsFailure>> createLightningToBitcoinSwap({
    required String walletId,
    required int amountSat,
    String? description,
  });

  Future<Result<LnReceiveSwap, SwapsFailure>> createLightningToLiquidSwap({
    required String walletId,
    required int amountSat,
    String? description,
  });

  Future<Result<ChainSwap, SwapsFailure>> createBitcoinToLiquidSwap({
    required String sendWalletId,
    required int amountSat,
    required ChainSwapDestination destination,
  });

  Future<Result<ChainSwap, SwapsFailure>> createLiquidToBitcoinSwap({
    required String sendWalletId,
    required int amountSat,
    required ChainSwapDestination destination,
  });

  /// The rescue key of the default Bitcoin wallet, if one was derived.
  Future<Result<SwapMasterKeyInfo?, SwapsFailure>> masterKeyInfo();

  /// The rescue key's words for [walletFingerprint], for display only.
  Future<Result<String?, SwapsFailure>> masterKeyMnemonic({
    required String walletFingerprint,
  });

  Future<Result<void, SwapsFailure>> deleteMasterKey();
}
