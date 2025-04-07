import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/features/send/domain/entities/payment_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'send_state.freezed.dart';

enum SendType {
  bitcoin,
  lightning,
  liquid;

  static SendType from(PaymentRequest paymentRequest) {
    switch (paymentRequest) {
      case BitcoinRequest():
        return SendType.bitcoin;
      case LiquidRequest():
        return SendType.liquid;
      case Bolt11Request():
        return SendType.lightning;
      case Bip21Request():
        switch (paymentRequest.scheme) {
          case 'bitcoin':
            return SendType.bitcoin;
          case 'liquid':
            return SendType.liquid;
          default:
            throw Exception('Unknown scheme: ${paymentRequest.scheme}');
        }
      default:
        throw Exception('Unknown payment type: ${paymentRequest.type}');
    }
  }
}

enum SendStep {
  address,
  amount,
  confirm,
  sending,
  sent,
}

@freezed
class SendState with _$SendState {
  const factory SendState({
    @Default(SendStep.address) SendStep step,
    @Default(SendType.lightning) SendType sendType,
    // input
    @Default('') String addressOrInvoice,
    Wallet? wallet,
    @Default('') String amount,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default('') String inputAmountCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String label,
    @Default([]) List<Utxo> utxos,
    @Default([]) List<Utxo> selectedUtxos,
    @Default(false) bool replaceByFee,
    FeeOptions? feesList,
    NetworkFee? selectedFee,
    int? customFee,
    // prepare
    String? bitcoinPsbt,
    String? liquidTransaction,
    LnSendSwap? lightningSwap,
    // confirm
    String? txId,
    Object? error,
  }) = _SendState;
  const SendState._();
}
