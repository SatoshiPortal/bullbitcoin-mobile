import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'swap_state.freezed.dart';

enum SwapPageStep { amount, confirm, sending, success }

enum WalletNetwork { bitcoin, liquid }

@freezed
abstract class SwapState with _$SwapState {
  const factory SwapState({
    @Default(SwapPageStep.amount) SwapPageStep step,
    // input
    @Default(true) bool loadingWallets,
    @Default([]) List<Wallet> fromWallets,
    @Default([]) List<Wallet> toWallets,
    @Default(WalletNetwork.bitcoin) WalletNetwork fromWalletNetwork,
    @Default(WalletNetwork.liquid) WalletNetwork toWalletNetwork,
    String? fromWalletId,
    String? toWalletId,
    @Default('') String fromAmount,
    @Default('') String toAmount,
    int? confirmedFromAmountSat,
    @Default('') String receiverAddress,

    // @Default([]) List<String> fromCurrencyCodes,
    // @Default([]) List<String> toCurrencyCodes,
    @Default('BTC') String selectedFromCurrencyCode,
    @Default('L-BTC') String selectedToCurrencyCode,

    @Default('') String amount,
    int? confirmedAmountSat,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('CAD') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String label,
    @Default([]) List<WalletUtxo> utxos,
    @Default([]) List<WalletUtxo> selectedUtxos,
    @Default(false) bool replaceByFee,
    FeeOptions? feesList,
    NetworkFee? selectedFee,
    // TODO: remove absFee and make usecases return size so abs fee can
    // be calculated from NetworkFee
    int? absoluteFees,
    FeeSelection? selectedFeeOption,
    int? customFee,
    // prepare
    String? unsignedPsbt,
    String? signedBitcoinPsbt,
    String? signedLiquidTx,
    ChainSwap? swap,
    // confirm
    String? txId,
    Object? error,
    @Default(false) bool sendMax,
    @Default(false) bool amountConfirmedClicked,
    @Default(false) bool creatingSwap,
    @Default(false) bool buildingTransaction,
    @Default(false) bool signingTransaction,
    @Default(false) bool broadcastingTransaction,
    @Default('') String balanceApproximatedAmount,
    SwapCreationException? swapCreationException,
    InsufficientBalanceException? insufficientBalanceException,
    InvalidBitcoinStringException? invalidBitcoinStringException,
    SwapLimitsException? swapLimitsException,
    BuildTransactionException? buildTransactionException,
    ConfirmTransactionException? confirmTransactionException,
    // swapLimits
    SwapLimits? swapLimits,
    SwapFees? swapFees,
  }) = _SwapState;
  const SwapState._();

  // Wallet? get liquidWallet {
  //   if (wallets.isEmpty) return null;
  //   return wallets.firstWhereOrNull((w) => w.isLiquid);
  // }

  // List<Wallet>? get bitcoinWallets {
  //   if (wallets.isEmpty) return null;
  //   return wallets.where((w) => !w.isLiquid).toList();
  // }

  List<({String id, String label})> get fromWalletDropdownItems {
    if (fromWallets.isEmpty) return [];
    return fromWallets.map((w) => (id: w.id, label: w.label)).toList();
  }

  List<({String id, String label})> get toWalletDropdownItems {
    if (toWallets.isEmpty) return [];
    return toWallets.map((w) => (id: w.id, label: w.label)).toList();
  }

  Wallet? get getFromWallets {
    if (fromWallets.isEmpty) return null;
    return fromWallets.firstWhereOrNull((w) => w.id == fromWalletId);
  }

  Wallet? get getToWallets {
    if (toWallets.isEmpty) return null;
    return toWallets.firstWhereOrNull((w) => w.id == toWalletId);
  }

  int get fromWalletBalance {
    if (getFromWallets == null) return 0;
    return getFromWallets!.balanceSat.toInt();
  }

  String formattedFromWalletBalance() {
    if (getFromWallets == null) return '0';

    if (bitcoinUnit == BitcoinUnit.btc) {
      return FormatAmount.btc(ConvertAmount.satsToBtc(fromWalletBalance));
    } else {
      return FormatAmount.sats(fromWalletBalance);
    }
  }

  bool get isInputAmountFiat =>
      ![BitcoinUnit.btc.code, BitcoinUnit.sats.code].contains(bitcoinUnit.code);

  int get inputAmountSat {
    int amountSat = 0;
    if (fromAmount.isNotEmpty) {
      if (isInputAmountFiat) {
        final amountFiat = double.tryParse(amount) ?? 0;
        amountSat = ConvertAmount.fiatToSats(amountFiat, exchangeRate);
      } else if (bitcoinUnit == BitcoinUnit.sats) {
        amountSat = int.tryParse(amount) ?? 0;
      } else {
        final amountBtc = double.tryParse(amount) ?? 0;
        amountSat = ConvertAmount.btcToSats(amountBtc);
      }
    }

    return amountSat;
  }

  double get inputAmountBtc => ConvertAmount.satsToBtc(inputAmountSat);

  double get inputAmountFiat {
    return ConvertAmount.btcToFiat(inputAmountBtc, exchangeRate);
  }

  double get confirmedAmountBtc =>
      confirmedAmountSat != null
          ? ConvertAmount.satsToBtc(confirmedAmountSat!)
          : 0;

  double get confirmedAmountFiat {
    return ConvertAmount.btcToFiat(confirmedAmountBtc, exchangeRate);
  }

  double get confirmedSwapAmountBtc =>
      swap != null ? ConvertAmount.satsToBtc(swap!.paymentAmount) : 0;

  String get formattedConfirmedAmountBitcoin {
    if (bitcoinUnit == BitcoinUnit.sats) {
      // For sats, use integer formatting without decimals
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit.code,
        decimalDigits: 0, // Use 0 decimals for sats
        customPattern: '#,##0 ¤',
      );
      return currencyFormatter.format(confirmedAmountSat ?? 0);
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

  String get formattedSwapAmountBitcoin {
    if (swap == null) return '0';
    if (bitcoinUnit == BitcoinUnit.sats) {
      // For sats, use integer formatting without decimals
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit.code,
        decimalDigits: 0, // Use 0 decimals for sats
        customPattern: '#,##0 ¤',
      );
      return currencyFormatter.format(swap!.paymentAmount);
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
    return FormatAmount.fiat(confirmedAmountFiat, fiatCurrencyCode);
  }

  String get formattedAmountInputEquivalent {
    if (isInputAmountFiat) {
      // If the input is in fiat, the equivalent should be in bitcoin
      if (bitcoinUnit == BitcoinUnit.sats) {
        // For sats, use integer formatting without decimals
        return FormatAmount.sats(inputAmountSat);
      } else {
        // For BTC, use the standard decimal formatting
        return FormatAmount.btc(inputAmountBtc);
      }
    } else {
      // If the input is in bitcoin, the equivalent should be in fiat
      return FormatAmount.fiat(inputAmountFiat, fiatCurrencyCode);
    }
  }

  // String formattedWalletBalance() {
  //   if (selectedWallet == null) return '0';

  //   if (bitcoinUnit == BitcoinUnit.btc.code) {
  //     return FormatAmount.btc(
  //       ConvertAmount.satsToBtc(selectedWallet!.balanceSat.toInt()),
  //     );
  //   } else if (bitcoinUnit == BitcoinUnit.sats.code) {
  //     return FormatAmount.sats(selectedWallet!.balanceSat.toInt());
  //   } else {
  //     return FormatAmount.fiat(
  //       ConvertAmount.satsToFiat(
  //         selectedWallet!.balanceSat.toInt(),
  //         exchangeRate,
  //       ),
  //       bitcoinUnit,
  //     );
  //   }
  // }

  // String formattedApproximateBalance() {
  //   if (selectedWallet == null) return '0';

  //   final satsBalance = selectedWallet!.balanceSat.toInt();

  //   if (bitcoinUnit == BitcoinUnit.btc.code ||
  //       bitcoinUnit == BitcoinUnit.sats.code) {
  //     return FormatAmount.fiat(
  //       ConvertAmount.satsToFiat(satsBalance, exchangeRate),
  //       fiatCurrencyCode,
  //     );
  //   } else {
  //     if (bitcoinUnit == BitcoinUnit.sats) {
  //       return FormatAmount.sats(satsBalance);
  //     } else {
  //       return FormatAmount.btc(ConvertAmount.satsToBtc(satsBalance));
  //     }
  //   }
  // }

  // bool walletHasBalance() {
  //   if (selectedWallet == null) return false;
  //   return inputAmountSat <= selectedWallet!.balanceSat.toInt();
  // }

  bool get swapAmountBelowLimit {
    if (inputAmountSat != 0) {
      return swapLimits != null && inputAmountSat < swapLimits!.min;
    }
    return false;
  }

  bool get swapAmountAboveLimit {
    return swapLimits != null && inputAmountSat > swapLimits!.max;
  }

  bool get isSwapAmountValid =>
      swapLimits == null ||
      inputAmountSat == 0 ||
      swapAmountBelowLimit ||
      swapAmountAboveLimit;

  bool get isSwapCompleted {
    return swap != null && swap!.status == SwapStatus.completed;
  }

  bool get disableContinueWithAmounts =>
      fromWalletBalance == 0 ||
      fromWalletBalance < inputAmountSat ||
      creatingSwap;
}
