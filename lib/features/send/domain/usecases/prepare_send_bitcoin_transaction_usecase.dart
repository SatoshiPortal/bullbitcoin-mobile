import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class PrepareSendBitcoinTransactionUsecase {
  final PrepareBitcoinSendUsecase _prepare;

  const PrepareSendBitcoinTransactionUsecase(this._prepare);

  @useResult
  Future<Result<PreparedBitcoinSend, SendFailure>> execute({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    List<WalletUtxo>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
    bool hasFrozenInputs = false,
  }) async {
    final result = await _prepare.execute(
      walletId: walletId,
      address: address,
      networkFee: networkFee,
      amountSat: amountSat,
      drain: drain,
      selectedInputs: selectedInputs,
      selectedOnly: selectedOnly,
      replaceByFee: replaceByFee,
    );
    final hasSelection = selectedInputs?.isNotEmpty ?? false;
    return result.mapErr(
      (failure) => switch (failure) {
        WalletSelectedInputsUnavailableFailure() =>
          SendSelectedCoinsUnavailableFailure(failure.logMessage),
        WalletNoSpendableInputsFailure() =>
          hasSelection
              ? SendSelectedCoinsUnavailableFailure(failure.logMessage)
              : SendInsufficientBalanceFailure(failure.logMessage),
        WalletInsufficientFundsFailure() =>
          hasSelection
              ? SendSelectedCoinsInsufficientFailure(failure.logMessage)
              : hasFrozenInputs
              ? SendInsufficientBalanceFailure(failure.logMessage)
              : SendInsufficientFundsForFeesFailure(failure.logMessage),
        WalletTransactionBuildFailure() => SendTransactionBuildFailure(
          failure.logMessage,
        ),
        _ => SendUnexpectedFailure(failure.logMessage),
      },
    );
  }
}
