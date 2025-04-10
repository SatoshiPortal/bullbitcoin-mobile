import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/features/send/domain/entities/payment_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

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

  String get displayName {
    switch (this) {
      case SendType.bitcoin:
        return 'Bitcoin';
      case SendType.lightning:
        return 'Lightning';
      case SendType.liquid:
        return 'Liquid';
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
    BigInt? confirmedAmountSat,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default('') String fiatApproximatedAmount,
    @Default('') String balanceApproximatedAmount,
    @Default('') String inputAmountCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String label,
    @Default([]) List<Utxo> utxos,
    @Default([]) List<Utxo> selectedUtxos,
    @Default(false) bool replaceByFee,
    FeeOptions? feesList,
    NetworkFee? selectedFee,
    FeeSelection? selectedFeeOption,
    int? customFee,
    // prepare
    String? unsignedPsbt,
    LnSendSwap? lightningSwap,
    // confirm
    String? txId,
    Object? error,
    @Default(false) bool sendMax,
    @Default(false) bool amountConfirmedClicked,
  }) = _SendState;
  const SendState._();
  bool get isInputAmountFiat => ![BitcoinUnit.btc.code, BitcoinUnit.sats.code]
      .contains(inputAmountCurrencyCode);
  BigInt get inputAmountSat {
    BigInt amountSat = BigInt.zero;

    if (amount.isNotEmpty) {
      if (isInputAmountFiat) {
        final amountFiat = double.tryParse(amount) ?? 0;
        amountSat = BigInt.from(
          amountFiat * 100000000 / exchangeRate,
        );
      } else if (inputAmountCurrencyCode == BitcoinUnit.sats.code) {
        amountSat = BigInt.tryParse(amount) ?? BigInt.zero;
      } else {
        final amountBtc = double.tryParse(amount) ?? 0;
        amountSat = BigInt.from((amountBtc * 100000000).truncate());
      }
    }

    return amountSat;
  }

  double get inputAmountBtc => inputAmountSat.toDouble() / 100000000;

  double get inputAmountFiat {
    return inputAmountBtc * exchangeRate;
  }

  double get confirmedAmountBtc => confirmedAmountSat != null
      ? confirmedAmountSat!.toDouble() / 100000000
      : 0;

  double get confirmedAmountFiat {
    return confirmedAmountBtc * exchangeRate;
  }

  String get formattedConfirmedAmountBitcoin {
    if (bitcoinUnit == BitcoinUnit.sats) {
      // For sats, use integer formatting without decimals
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit.code,
        decimalDigits: 0, // Use 0 decimals for sats
        customPattern: '#,##0 ¤',
      );
      return currencyFormatter.format(confirmedAmountSat?.toInt() ?? 0);
    } else {
      // For BTC, use the standard decimal formatting
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit.code,
        decimalDigits: bitcoinUnit.decimals,
        customPattern: '#,##0.00 ¤',
      );
      final formatted = currencyFormatter
          .format(confirmedAmountBtc)
          .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
      return formatted;
    }
  }

  String get formattedConfirmedAmountFiat {
    final currencyFormatter = NumberFormat.currency(
      name: fiatCurrencyCode,
      customPattern: '#,##0.00 ¤',
    );
    final formatted = currencyFormatter.format(confirmedAmountFiat);
    return formatted;
  }

  String get formattedAmountInputEquivalent {
    if (isInputAmountFiat) {
      // If the input is in fiat, the equivalent should be in bitcoin
      if (bitcoinUnit == BitcoinUnit.sats) {
        // For sats, use integer formatting without decimals
        final currencyFormatter = NumberFormat.currency(
          name: bitcoinUnit.code,
          decimalDigits: 0, // Use 0 decimals for sats
          customPattern: '#,##0 ¤',
        );
        return currencyFormatter.format(inputAmountSat.toInt());
      } else {
        // For BTC, use the standard decimal formatting
        final currencyFormatter = NumberFormat.currency(
          name: bitcoinUnit.code,
          decimalDigits: bitcoinUnit.decimals,
          customPattern: '#,##0.00 ¤',
        );
        final formatted = currencyFormatter
            .format(inputAmountBtc)
            .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
        return formatted;
      }
    } else {
      // If the input is in bitcoin, the equivalent should be in fiat
      final currencyFormatter = NumberFormat.currency(
        name: fiatCurrencyCode,
        customPattern: '#,##0.00 ¤',
      );
      final formatted = currencyFormatter.format(inputAmountFiat);
      return formatted;
    }
  }
}
