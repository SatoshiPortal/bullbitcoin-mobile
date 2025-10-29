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
}
