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
  const factory ReceiveEvent.receiveNewAddressGenerated() =
      ReceiveNewAddressGenerated;
  const factory ReceiveEvent.receivePayjoinUpdated(
    PayjoinReceiverSession payjoin,
  ) = ReceivePayjoinUpdated;
  const factory ReceiveEvent.receivePayjoinOriginalTxBroadcasted() =
      ReceivePayjoinOriginalTxBroadcasted;
  const factory ReceiveEvent.receiveTransactionReceived(WalletTransaction tx) =
      ReceiveTransactionReceived;
  const factory ReceiveEvent.receivePayjoinSettingChanged(bool enabled) =
      ReceivePayjoinSettingChanged;
  const factory ReceiveEvent.receivePayjoinMinAmountChanged(int amountSat) =
      ReceivePayjoinMinAmountChanged;
  const factory ReceiveEvent.receivePayjoinToggled(
    bool enabled,
    Future<bool> Function() requestConsent,
  ) = ReceivePayjoinToggled;
  const factory ReceiveEvent.receiveOrderSwapUpdated(
    Result<OrderSwapRecord, ReceiveFailure> result,
  ) = ReceiveOrderSwapUpdated;
}
