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

    @Default('BTC') String selectedFromCurrencyCode,
    @Default('L-BTC') String selectedToCurrencyCode,
    (SwapLimits, SwapFees)? btcToLbtcSwapLimitsAndFees,
    (SwapLimits, SwapFees)? lbtcToBtcSwapLimitsAndFees,
    int? confirmedAmountSat,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,

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

  String get estimatedFeesFormatted {
    int totalFees = 0;
    if (fromWalletNetwork == WalletNetwork.bitcoin &&
        toWalletNetwork == WalletNetwork.liquid) {
      totalFees = estimatedBtcToLbtcSwapFees;
    } else {
      totalFees = estimatedLbtcToBtcSwapFees;
    }
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(totalFees);
    } else {
      return FormatAmount.btc(ConvertAmount.satsToBtc(totalFees));
    }
  }

  int get estimatedBtcToLbtcSwapFees {
    if (btcToLbtcSwapLimitsAndFees == null) return 0;
    return btcToLbtcSwapLimitsAndFees!.$2.totalFees(fromAmountSat) ?? 0;
  }

  int get estimatedLbtcToBtcSwapFees {
    if (lbtcToBtcSwapLimitsAndFees == null) return 0;
    return lbtcToBtcSwapLimitsAndFees!.$2.totalFees(fromAmountSat) ?? 0;
  }

  List<({String id, String label})> get fromWalletDropdownItems {
    if (fromWallets.isEmpty) return [];
    return fromWallets.map((w) => (id: w.id, label: w.label)).toList();
  }

  List<({String id, String label})> get toWalletDropdownItems {
    if (toWallets.isEmpty) return [];
    return toWallets.map((w) => (id: w.id, label: w.label)).toList();
  }

  Wallet? get fromWallet {
    if (fromWallets.isEmpty) return null;
    return fromWallets.firstWhereOrNull((w) => w.id == fromWalletId);
  }

  Wallet? get toWallet {
    if (toWallets.isEmpty) return null;
    return toWallets.firstWhereOrNull((w) => w.id == toWalletId);
  }

  int get fromWalletBalance {
    if (fromWallet == null) return 0;
    return fromWallet!.balanceSat.toInt();
  }

  String formattedFromWalletBalance() {
    if (fromWallet == null) return '0';

    if (bitcoinUnit == BitcoinUnit.btc) {
      return FormatAmount.btc(ConvertAmount.satsToBtc(fromWalletBalance));
    } else {
      return FormatAmount.sats(fromWalletBalance);
    }
  }

  bool get isInputAmountFiat =>
      ![BitcoinUnit.btc.code, BitcoinUnit.sats.code].contains(bitcoinUnit.code);

  int get fromAmountSat {
    int amountSat = 0;
    if (fromAmount.isNotEmpty) {
      if (bitcoinUnit == BitcoinUnit.sats) {
        amountSat = int.tryParse(fromAmount) ?? 0;
      } else {
        final amountBtc = double.tryParse(fromAmount) ?? 0;
        amountSat = ConvertAmount.btcToSats(amountBtc);
      }
    }

    return amountSat;
  }

  int get toAmountSat {
    int amountSat = 0;
    if (toAmount.isNotEmpty) {
      if (bitcoinUnit == BitcoinUnit.sats) {
        amountSat = int.tryParse(toAmount) ?? 0;
      } else {
        final amountBtc = double.tryParse(toAmount) ?? 0;
        amountSat = ConvertAmount.btcToSats(amountBtc);
      }
    }

    return amountSat;
  }

  String get calculateToAmount {
    if (fromAmount.isEmpty) return '';
    int amountSat = 0;
    if (fromWalletNetwork == WalletNetwork.bitcoin &&
        toWalletNetwork == WalletNetwork.liquid) {
      amountSat = fromAmountSat - estimatedBtcToLbtcSwapFees;
    } else {
      amountSat = fromAmountSat - estimatedLbtcToBtcSwapFees;
    }
    if (bitcoinUnit == BitcoinUnit.btc) {
      return FormatAmount.btc(ConvertAmount.satsToBtc(amountSat));
    } else {
      return amountSat.toString();
    }
  }

  String get formattedFromAmountEquivalent {
    if (fromAmount.isEmpty) return '0';
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.btc(ConvertAmount.satsToBtc(fromAmountSat));
    } else {
      return FormatAmount.sats(fromAmountSat);
    }
  }

  String get formattedToAmount {
    if (toAmount.isEmpty) return '0';
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(toAmountSat);
    } else {
      return FormatAmount.btc(ConvertAmount.satsToBtc(toAmountSat));
    }
  }

  String get formattedToAmountEquivalent {
    if (toAmount.isEmpty) return '0';
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.btc(ConvertAmount.satsToBtc(toAmountSat));
    } else {
      return FormatAmount.sats(toAmountSat);
    }
  }

  double get inputAmountBtc => ConvertAmount.satsToBtc(fromAmountSat);

  double get confirmedAmountBtc =>
      confirmedAmountSat != null
          ? ConvertAmount.satsToBtc(confirmedAmountSat!)
          : 0;

  double get confirmedSwapAmountBtc =>
      swap != null ? ConvertAmount.satsToBtc(swap!.paymentAmount) : 0;

  bool get swapAmountBelowLimit {
    if (fromAmountSat != 0) {
      return swapLimits != null && fromAmountSat < swapLimits!.min;
    }
    return false;
  }

  bool get swapAmountAboveLimit {
    return swapLimits != null && fromAmountSat > swapLimits!.max;
  }

  bool get isSwapAmountValid =>
      swapLimits == null ||
      fromAmountSat == 0 ||
      swapAmountBelowLimit ||
      swapAmountAboveLimit;

  bool get isSwapCompleted {
    return swap != null && swap!.status == SwapStatus.completed;
  }

  bool get disableContinueWithAmounts =>
      fromWalletBalance == 0 ||
      // fromWalletBalance < fromAmountSat ||
      creatingSwap ||
      amountConfirmedClicked;
}

class SwapCreationException implements Exception {
  final String message;

  SwapCreationException(this.message);

  @override
  String toString() => message;
  String get displayMessage => 'Failed to create swap.';
}
