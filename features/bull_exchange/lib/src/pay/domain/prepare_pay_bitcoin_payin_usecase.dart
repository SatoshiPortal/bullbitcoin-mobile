import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

import 'package:sync/sync.dart';
import 'package:fees/fees.dart';

class PreparePayBitcoinPayinUsecase {
  final Spend _spend;

  const PreparePayBitcoinPayinUsecase(this._spend);

  @useResult
  Future<Result<PreparedBitcoinSpend, PayFailure>> execute({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    List<Coin>? selectedInputs,
    bool replaceByFee = true,
  }) async {
    final BitcoinTransactionRecipient recipient;
    if (drain) {
      recipient = BitcoinTransactionRecipient.remainder(address: address);
    } else if (amountSat != null) {
      recipient = BitcoinTransactionRecipient.fixed(
        address: address,
        amountSat: Sats.fromInt(amountSat),
      );
    } else {
      return const Err(PayUnexpectedFailure('Amount required'));
    }
    final recipients = [recipient];
    final result = await _spend.prepareBitcoin(
      walletId: walletId,
      recipients: recipients,
      networkFee: networkFee,
      selectedInputs: selectedInputs?.map((coin) => coin.outpoint).toSet(),
      replaceByFee: replaceByFee,
    );
    return result.mapErr(
      (failure) => switch (failure) {
        SpendUnavailableFailure(:final busy) => PaySpendBlockedFailure(
          busy: busy,
        ),
        SpendInsufficientFundsFailure() ||
        SpendInsufficientFundsForFeesFailure() ||
        SpendNoSpendableInputsFailure() ||
        SpendSelectedInputsUnavailableFailure() =>
          PayInsufficientBalanceFailure(requiredAmountSat: amountSat ?? 0),
        _ => const PayUnexpectedFailure(),
      },
    );
  }
}
