import 'package:bb_mobile/features/send/public/send_facade.dart'
    show BitcoinSpendStatus, WalletSpendBlockedException;
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:fees/fees.dart';
import 'package:bb_mobile/features/coins/domain/wallet_utxo.dart';
import 'package:bb_mobile/features/send/public/send_setup.dart'
    show PrepareBitcoinSendUsecase, PreparedBitcoinSend;
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// What a built Bitcoin pay payin is worth knowing about.
typedef PreparedPayBitcoinPayin = ({
  String unsignedPsbt,
  int txSize,
  bool isToSelf,
});

/// Builds the unsigned PSBT for a Bitcoin pay payin.
class PreparePayBitcoinPayinUsecase {
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;

  const PreparePayBitcoinPayinUsecase({
    required this._prepareBitcoinSendUsecase,
  });

  @useResult
  Future<Result<PreparedPayBitcoinPayin, PayFailure>> execute({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    List<WalletUtxo>? selectedInputs,
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
    final Result<PreparedBitcoinSend, WalletFailure> result;
    try {
      result = await _prepareBitcoinSendUsecase.execute(
        walletId: walletId,
        recipients: [recipient],
        networkFee: networkFee,
        selectedInputs: selectedInputs,
        replaceByFee: replaceByFee,
      );
    } on WalletSpendBlockedException catch (e) {
      return Err(
        PaySpendBlockedFailure(busy: e.status == BitcoinSpendStatus.busy),
      );
    }
    return result
        .map(
          (prepared) => (
            unsignedPsbt: prepared.unsignedPsbt,
            txSize: prepared.txSize,
            isToSelf: prepared.isToSelf,
          ),
        )
        .mapErr(
          (failure) => switch (failure) {
            WalletInsufficientFundsFailure() ||
            WalletNoSpendableInputsFailure() ||
            WalletSelectedInputsUnavailableFailure() =>
              PayInsufficientBalanceFailure(
                requiredAmountSat: amountSat ?? 0,
                logMessage: failure.logMessage,
              ),
            _ => PayUnexpectedFailure(failure.logMessage),
          },
        );
  }
}
