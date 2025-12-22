part of 'transfer_bloc.dart';

@freezed
sealed class TransferEvent with _$TransferEvent {
  const factory TransferEvent.started() = TransferStarted;
  const factory TransferEvent.walletsChanged({
    required Wallet fromWallet,
    required Wallet toWallet,
  }) = TransferWalletsChanged;
  const factory TransferEvent.amountChanged(String amount) =
      TransferAmountChanged;
  const factory TransferEvent.swapCreated(String amount) = TransferSwapCreated;
  const factory TransferEvent.confirmed() = TransferConfirmed;
  const factory TransferEvent.sendToExternalToggled(bool enabled) =
      TransferSendToExternalToggled;
  const factory TransferEvent.externalAddressChanged(String address) =
      TransferExternalAddressChanged;
  const factory TransferEvent.receiveExactAmountToggled(bool enabled) =
      TransferReceiveExactAmountToggled;
  const factory TransferEvent.replaceByFeeChanged(bool replaceByFee) =
      TransferReplaceByFeeChanged;
  const factory TransferEvent.utxosSelected(List<WalletUtxo> utxos) =
      TransferUtxosSelected;
  const factory TransferEvent.loadUtxos() = TransferLoadUtxos;
  const factory TransferEvent.feeOptionSelected(FeeSelection feeSelection) =
      TransferFeeOptionSelected;
  const factory TransferEvent.customFeeChanged(NetworkFee fee) =
      TransferCustomFeeChanged;
}
