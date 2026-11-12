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
    final result = await _prepareBitcoinSendUsecase.execute(
      walletId: walletId,
      address: address,
      networkFee: networkFee,
      amountSat: amountSat,
      drain: drain,
      selectedInputs: selectedInputs,
      replaceByFee: replaceByFee,
    );
    return result.mapErr(
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
