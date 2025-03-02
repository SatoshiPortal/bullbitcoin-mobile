part of 'receive_bloc.dart';

enum ReceiveStatus { initial, inProgress, success, error }

enum ReceivePaymentNetwork { bitcoin, lightning, liquid }

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState({
    @Default(ReceiveStatus.initial) ReceiveStatus status,
    @Default(ReceivePaymentNetwork.bitcoin)
    ReceivePaymentNetwork paymentNetwork,
    List<Wallet>? wallets,
    String? selectedWalletId,
    @Default(false) bool isFiatInput,
    String? fiatCurrencyCode,
    double? exchangeRate,
    BitcoinUnit? bitcoinUnit,
    @Default('') String fiatInputAmount,
    @Default('') String bitcoinInputAmount,
    @Default('') String description,
    BigInt? feeAmountSat,
    @Default('') String invoice,
    @Default(false) bool isPayjoinEnabled,
  }) = _ReceiveState;
  const ReceiveState._();

  bool get hasReceivedFunds => status == ReceiveStatus.success;
}
