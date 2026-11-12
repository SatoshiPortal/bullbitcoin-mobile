import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Builds the unsigned PSET for a Liquid sell payin.
class PrepareSellLiquidPayinUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  const PrepareSellLiquidPayinUsecase({required this._liquidWalletRepository});

  @useResult
  Future<Result<String, SellFailure>> execute({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
  }) async {
    if (amountSat == null && !drain) {
      log.severe(
        error: 'prepareSellLiquidPayin called without an amount and no drain',
        trace: StackTrace.current,
      );
      return const Err(
        SellUnexpectedFailure('amount required unless draining'),
      );
    }

    final result = await _liquidWalletRepository.buildPset(
      walletId: walletId,
      address: address,
      amountSat: drain ? null : amountSat,
      feeRate: feeRate,
      drain: drain,
    );
    return result.mapErr(
      (failure) => switch (failure) {
        WalletInsufficientFundsFailure() || WalletNoSpendableInputsFailure() =>
          SellInsufficientBalanceFailure(requiredAmountSat: amountSat ?? 0),
        _ => const SellUnexpectedFailure(),
      },
    );
  }
}
