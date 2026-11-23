import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

import 'package:sync/sync.dart';
import 'package:fees/fees.dart';

class PrepareSellBitcoinPayinUsecase {
  final Spend _spend;

  const PrepareSellBitcoinPayinUsecase(this._spend);

  @useResult
  Future<Result<PreparedBitcoinSpend, SellFailure>> execute({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    List<Coin>? selectedInputs,
    bool replaceByFee = true,
  }) async {
    final result = await _spend.prepareBitcoin(
      walletId: walletId,
      recipients: recipients,
      networkFee: networkFee,
      selectedInputs: selectedInputs?.map((coin) => coin.outpoint).toSet(),
      replaceByFee: replaceByFee,
    );
    return result.mapErr(
      (failure) => switch (failure) {
        SpendUnavailableFailure(:final busy) => SellSpendBlockedFailure(
          busy: busy,
        ),
        SpendInsufficientFundsFailure() ||
        SpendInsufficientFundsForFeesFailure() ||
        SpendNoSpendableInputsFailure() ||
        SpendSelectedInputsUnavailableFailure() =>
          SellInsufficientBalanceFailure(
            requiredAmountSat: recipients.fold(
              0,
              (total, recipient) =>
                  total + (recipient.amountSat?.value.toInt() ?? 0),
            ),
          ),
        _ => const SellUnexpectedFailure(),
      },
    );
  }
}
