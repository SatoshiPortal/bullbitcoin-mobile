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
  liquid,
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

  SendType sendTypeFromRequest(PaymentRequest request) {
    // BitcoinAddressOnly - bdk.Address
    // LiquidAddressOnly - lwk.Address
    // BitcoinBip21 - bdk.Address
    // LiquidBip21 - lwk.Address
    // Bolt11 - boltz.DecodedInvoice
    // Bolt12 - boltz (pending)

    if (request is BitcoinRequest) {
      return SendType.bitcoin;
    } else if (request is LiquidRequest) {
      return SendType.liquid;
    } else if (request is Bolt11Request) {
      return SendType.lightning;
    } else if (request is Bip21Request) {
      if (request.scheme == 'bitcoin') {
        return SendType.bitcoin;
      } else if (request.scheme == 'liquid') {
        return SendType.liquid;
      } else {
        throw Exception('Unknown scheme: ${request.scheme}');
      }
    } else {
      throw Exception('Unknown request type: ${request.runtimeType}');
    }
  }
}
