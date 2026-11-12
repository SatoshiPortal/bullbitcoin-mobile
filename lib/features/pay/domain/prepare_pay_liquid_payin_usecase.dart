import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Builds the unsigned PSET for a Liquid pay payin.
class PreparePayLiquidPayinUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  const PreparePayLiquidPayinUsecase({required this._liquidWalletRepository});

  @useResult
  Future<Result<String, PayFailure>> execute({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
  }) async {
    if (amountSat == null && !drain) {
      log.severe(
        error: 'preparePayLiquidPayin called without an amount and no drain',
        trace: StackTrace.current,
      );
      return const Err(PayUnexpectedFailure('amount required unless draining'));
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
          PayInsufficientBalanceFailure(requiredAmountSat: amountSat ?? 0),
        _ => const PayUnexpectedFailure(),
      },
    );
  }
}
