import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap_state.freezed.dart';

enum SwapPageStep { amount, confirm, progress, success }

enum WalletNetwork { bitcoin, liquid }

@freezed
abstract class SwapState with _$SwapState {
  const factory SwapState({
    @Default(SwapPageStep.amount) SwapPageStep step,
    // input
    @Default(true) bool loadingWallets,
    @Default([]) List<Wallet> fromWallets,
    @Default([]) List<Wallet> toWallets,
    @Default(WalletNetwork.liquid) WalletNetwork fromWalletNetwork,
    @Default(WalletNetwork.bitcoin) WalletNetwork toWalletNetwork,
    String? fromWalletId,
    String? toWalletId,
    @Default('') String fromAmount,
    @Default('') String toAmount,
    @Default('') String receiverAddress,
    @Default('BTC') String selectedFromCurrencyCode,
    @Default('L-BTC') String selectedToCurrencyCode,
    (SwapLimits, SwapFees)? btcToLbtcSwapLimitsAndFees,
    (SwapLimits, SwapFees)? lbtcToBtcSwapLimitsAndFees,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,

    @Default('') String label,
    @Default([]) List<WalletUtxo> utxos,
    @Default([]) List<WalletUtxo> selectedUtxos,
    @Default(false) bool replaceByFee,
    FeeOptions? selectedFeeList,
    FeeOptions? bitcoinFeeList,
    FeeOptions? liquidFeeList,
    NetworkFee? selectedFee,
    // TODO: remove absFee and make usecases return size so abs fee can
    // be calculated from NetworkFee
    int? bitcoinAbsoluteFees,
    int? liquidAbsoluteFees,
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

    @Default([]) List<String> fiatCurrencyCodes,
    @Default('CAD') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
  }) = _SwapState;
  const SwapState._();

  int? get absoluteFees {
    if (fromWalletNetwork == WalletNetwork.liquid) {
      return liquidAbsoluteFees;
    } else {
      return bitcoinAbsoluteFees;
    }
  }

  String get absoluteFeesFormatted {
    if (absoluteFees == null) return '0';
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(absoluteFees!);
    } else {
      return FormatAmount.btc(ConvertAmount.satsToBtc(absoluteFees!));
    }
  }

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
    return btcToLbtcSwapLimitsAndFees!.$2.totalFees(fromAmountSat);
  }

  int get estimatedLbtcToBtcSwapFees {
    if (lbtcToBtcSwapLimitsAndFees == null) return 0;
    return lbtcToBtcSwapLimitsAndFees!.$2.totalFees(fromAmountSat);
  }

  List<({String id, String label})> get fromWalletDropdownItems {
    if (fromWallets.isEmpty) return [];
    return fromWallets.map((w) => (id: w.id, label: w.displayLabel)).toList();
  }

  List<({String id, String label})> get toWalletDropdownItems {
    if (toWallets.isEmpty) return [];
    return toWallets.map((w) => (id: w.id, label: w.displayLabel)).toList();
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

  String get fromWalletLabel {
    if (fromWallet == null) return '';
    return fromWallet!.displayLabel;
  }

  String get toWalletLabel {
    if (toWallet == null) return '';
    return toWallet!.displayLabel;
  }

  String formattedFromWalletBalance() {
    if (fromWallet == null) return '0';

    if (isInputAmountFiat) {
      return FormatAmount.fiat(
        ConvertAmount.satsToFiat(fromWalletBalance, exchangeRate),
        selectedFromCurrencyCode,
      );
    } else if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(fromWalletBalance);
    } else {
      return FormatAmount.btc(ConvertAmount.satsToBtc(fromWalletBalance));
    }
  }

  List<String> get inputAmountCurrencyCodes {
    return [BitcoinUnit.btc.code, BitcoinUnit.sats.code];
  }

  bool get isInputAmountFiat =>
      ![
        BitcoinUnit.btc.code,
        BitcoinUnit.sats.code,
      ].contains(selectedFromCurrencyCode);

  bool get isOutAmountFiat =>
      ![
        BitcoinUnit.btc.code,
        BitcoinUnit.sats.code,
      ].contains(selectedToCurrencyCode);

  String get displayToCurrencyCode {
    if (toWallet?.isLiquid ?? false) {
      if (selectedToCurrencyCode == BitcoinUnit.sats.code) {
        return 'L-sats';
      } else if (selectedToCurrencyCode == BitcoinUnit.btc.code) {
        return 'L-BTC';
      }
    }
    return selectedToCurrencyCode;
  }

  String get displayFromCurrencyCode {
    if (fromWallet?.isLiquid ?? true) {
      if (selectedFromCurrencyCode == BitcoinUnit.sats.code) {
        return 'L-sats';
      } else if (selectedFromCurrencyCode == BitcoinUnit.btc.code) {
        return 'L-BTC';
      }
    }
    return selectedFromCurrencyCode;
  }

  int get fromAmountSat {
    int amountSat = 0;
    if (fromAmount.isNotEmpty) {
      if (isInputAmountFiat) {
        final amountFiat = double.tryParse(fromAmount) ?? 0;
        amountSat = ConvertAmount.fiatToSats(amountFiat, exchangeRate);
      } else if (bitcoinUnit == BitcoinUnit.sats) {
        amountSat = int.tryParse(fromAmount) ?? 0;
      } else {
        final amountBtc = double.tryParse(fromAmount) ?? 0;
        amountSat = ConvertAmount.btcToSats(amountBtc);
      }
    }
    return amountSat;
  }

  double get fromAmountFiat {
    return ConvertAmount.btcToFiat(fromAmountBtc, exchangeRate);
  }

  double get fromAmountBtc => ConvertAmount.satsToBtc(fromAmountSat);

  String get formattedFromAmountEquivalent {
    if (fromAmount.isEmpty) return '0';
    if (isInputAmountFiat) {
      if (bitcoinUnit == BitcoinUnit.sats) {
        return FormatAmount.sats(fromAmountSat);
      } else {
        return FormatAmount.btc(fromAmountBtc);
      }
    } else {
      return FormatAmount.fiat(fromAmountFiat, fiatCurrencyCode);
    }
  }

  int get toAmountSat {
    int amountSat = 0;
    if (toAmount.isNotEmpty) {
      if (isOutAmountFiat) {
        final amountFiat = double.tryParse(toAmount) ?? 0;
        amountSat = ConvertAmount.fiatToSats(amountFiat, exchangeRate);
      } else if (bitcoinUnit == BitcoinUnit.sats) {
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
      if (amountSat < 0) {
        amountSat = 0;
      }
    } else {
      amountSat = fromAmountSat - estimatedLbtcToBtcSwapFees;
      if (amountSat < 0) {
        amountSat = 0;
      }
    }

    if (isOutAmountFiat) {
      // Convert to fiat and format
      final amountFiat = ConvertAmount.btcToFiat(
        ConvertAmount.satsToBtc(amountSat),
        exchangeRate,
      );
      return amountFiat.toString();
    } else if (bitcoinUnit == BitcoinUnit.btc) {
      return ConvertAmount.satsToBtc(amountSat).toString();
    } else {
      return amountSat.toString();
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
    if (isOutAmountFiat) {
      if (bitcoinUnit == BitcoinUnit.sats) {
        final formatted = FormatAmount.sats(toAmountSat);
        if (toWallet?.isLiquid ?? false) {
          return formatted.replaceAll('sats', 'L-sats');
        } else {
          return formatted;
        }
      } else {
        final formatted = FormatAmount.btc(
          ConvertAmount.satsToBtc(toAmountSat),
        );
        if (toWallet?.isLiquid ?? false) {
          return formatted.replaceAll('BTC', 'L-BTC');
        } else {
          return formatted;
        }
      }
    } else {
      return FormatAmount.fiat(
        ConvertAmount.btcToFiat(
          ConvertAmount.satsToBtc(toAmountSat),
          exchangeRate,
        ),
        fiatCurrencyCode,
      );
    }
  }

  String get formattedConfirmedAmountBitcoin {
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(fromAmountSat);
    } else {
      return FormatAmount.btc(ConvertAmount.satsToBtc(fromAmountSat));
    }
  }

  double get inputAmountBtc => ConvertAmount.satsToBtc(fromAmountSat);

  double get confirmedAmountBtc => ConvertAmount.satsToBtc(fromAmountSat);

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

  bool walletHasBalanceIncludingFees() {
    if (fromWallet == null) return false;
    if (fromWalletBalance == 0) return false;
    if (fromWalletNetwork == WalletNetwork.bitcoin &&
        toWalletNetwork == WalletNetwork.liquid) {
      return fromWalletBalance >= fromAmountSat + (absoluteFees ?? 0);
    } else {
      return fromWalletBalance >= fromAmountSat + (liquidAbsoluteFees ?? 0);
    }
  }

  bool get disableContinueWithAmounts =>
      amountConfirmedClicked ||
      fromAmountSat == 0 ||
      toAmountSat <= 0 ||
      fromWalletBalance < fromAmountSat ||
      creatingSwap;

  bool get disableSendSwapButton =>
      broadcastingTransaction || signingTransaction || buildingTransaction;

  SwapLimits? get swapLimits {
    if (fromWalletNetwork == WalletNetwork.bitcoin &&
        toWalletNetwork == WalletNetwork.liquid) {
      return btcToLbtcSwapLimitsAndFees?.$1;
    } else if (fromWalletNetwork == WalletNetwork.liquid &&
        toWalletNetwork == WalletNetwork.bitcoin) {
      return lbtcToBtcSwapLimitsAndFees?.$1;
    }
    return null;
  }

  SwapFees? get swapFees {
    if (fromWalletNetwork == WalletNetwork.bitcoin &&
        toWalletNetwork == WalletNetwork.liquid) {
      return btcToLbtcSwapLimitsAndFees?.$2;
    } else if (fromWalletNetwork == WalletNetwork.liquid &&
        toWalletNetwork == WalletNetwork.bitcoin) {
      return lbtcToBtcSwapLimitsAndFees?.$2;
    }
    return null;
  }
}
