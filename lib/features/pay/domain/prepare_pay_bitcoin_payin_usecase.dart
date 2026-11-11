import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
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
    final result = await _prepareBitcoinSendUsecase.execute(
      walletId: walletId,
      recipients: [recipient],
      networkFee: networkFee,
      selectedInputs: selectedInputs,
      replaceByFee: replaceByFee,
    );
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
