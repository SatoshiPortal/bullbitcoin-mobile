part of 'receive_bloc.dart';

@freezed
class ReceiveEvent with _$ReceiveEvent {
  const factory ReceiveEvent.receiveBitcoinStarted() = ReceiveBitcoinStarted;
  const factory ReceiveEvent.receiveLightningStarted() =
      ReceiveLightningStarted;
  const factory ReceiveEvent.receiveLiquidStarted() = ReceiveLiquidStarted;
  const factory ReceiveEvent.receiveAmountCurrencyChanged(String currencyCode) =
      ReceiveAmountCurrencyChanged;
  const factory ReceiveEvent.receiveAmountChanged(String amount) =
      ReceiveAmountChanged;
  const factory ReceiveEvent.receiveNoteChanged(String note) =
      ReceiveNoteChanged;
  const factory ReceiveEvent.receiveAddressOnlyToggled() =
      ReceiveAddressOnlyToggled;
  const factory ReceiveEvent.receiveNewAddressGenerated() =
      ReceiveNewAddressGenerated;
  const factory ReceiveEvent.receiveLightningSwapCreated() =
      ReceiveLightningSwapCreated;
  const factory ReceiveEvent.receivePaymentReceived() = ReceivePaymentReceived;
}
