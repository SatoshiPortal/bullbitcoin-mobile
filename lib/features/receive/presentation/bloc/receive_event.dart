part of 'receive_bloc.dart';

@freezed
class ReceiveEvent with _$ReceiveEvent {
  const factory ReceiveEvent.receiveBitcoinStarted(Wallet? wallet) =
      ReceiveBitcoinStarted;
  const factory ReceiveEvent.receiveLightningStarted() =
      ReceiveLightningStarted;
  const factory ReceiveEvent.receiveLiquidStarted() = ReceiveLiquidStarted;
  const factory ReceiveEvent.receiveAmountCurrencyChanged(String currencyCode) =
      ReceiveAmountCurrencyChanged;
  const factory ReceiveEvent.receiveAmountInputChanged(String amount) =
      ReceiveAmountInputChanged;
  const factory ReceiveEvent.receiveAmountConfirmed() = ReceiveAmountConfirmed;
  const factory ReceiveEvent.receiveNoteChanged(String note) =
      ReceiveNoteChanged;
  const factory ReceiveEvent.receiveNoteSaved() = ReceiveNoteSaved;
  const factory ReceiveEvent.receiveAddressOnlyToggled(bool isAddressOnly) =
      ReceiveAddressOnlyToggled;
  const factory ReceiveEvent.receiveNewAddressGenerated() =
      ReceiveNewAddressGenerated;
  const factory ReceiveEvent.receivePayjoinUpdated(PayjoinReceiver payjoin) =
      ReceivePayjoinUpdated;
  const factory ReceiveEvent.receivePayjoinOriginalTxBroadcasted() =
      ReceivePayjoinOriginalTxBroadcasted;
  const factory ReceiveEvent.receiveTransactionReceived(WalletTransaction tx) =
      ReceiveTransactionReceived;
  const factory ReceiveEvent.receiveLightningSwapUpdated(LnReceiveSwap swap) =
      ReceiveLightningSwapUpdated;
}
