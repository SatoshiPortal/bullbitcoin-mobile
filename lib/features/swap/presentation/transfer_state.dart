part of 'transfer_bloc.dart';

@freezed
sealed class TransferState with _$TransferState {
  const factory TransferState({
    @Default(false) bool isStarting,
    Exception? startError,
    @Default([]) List<Wallet> wallets,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    FeeOptions? liquidNetworkFees,
    FeeOptions? bitcoinNetworkFees,
    (SwapLimits, SwapFees)? btcToLbtcSwapLimitsAndFees,
    (SwapLimits, SwapFees)? lbtcToBtcSwapLimitsAndFees,
    Wallet? fromWallet,
    Wallet? toWallet,
    int? maxAmountSat,
    @Default(false) bool isCreatingSwap,
    SwapCreationException? swapCreationException,
    ChainSwap? swap,
    @Default('') String signedPsbt,
    int? bitcoinAbsoluteFeesSat,
    int? liquidAbsoluteFeesSat,
    @Default(false) bool isConfirming,
    ConfirmTransactionException? confirmTransactionException,
    @Default('') String txId,
    @Default(false) bool sendToExternal,
    @Default('') String externalAddress,
    String? externalAddressError,
    @Default(true) bool sendExactAmount,
    @Default('') String amount,
  }) = _TransferState;
  const TransferState._();

  String get displayToCurrencyCode {
    return '${toWallet?.isLiquid ?? false ? 'L-' : ''}${bitcoinUnit.code}';
  }

  String get displayFromCurrencyCode {
    return '${fromWallet?.isLiquid ?? false ? 'L-' : ''}${bitcoinUnit.code}';
  }

  SwapLimits? get swapLimits {
    if (sendToExternal) {
      if (fromWallet?.isLiquid == false) {
        return btcToLbtcSwapLimitsAndFees?.$1;
      } else if (fromWallet?.isLiquid == true) {
        return lbtcToBtcSwapLimitsAndFees?.$1;
      }
    } else {
      if (fromWallet?.isLiquid == false && toWallet?.isLiquid == true) {
        return btcToLbtcSwapLimitsAndFees?.$1;
      } else if (fromWallet?.isLiquid == true && toWallet?.isLiquid == false) {
        return lbtcToBtcSwapLimitsAndFees?.$1;
      }
    }
    return null;
  }

  SwapFees? get swapFees {
    if (sendToExternal) {
      if (fromWallet?.isLiquid == false) {
        return btcToLbtcSwapLimitsAndFees?.$2;
      } else if (fromWallet?.isLiquid == true) {
        return lbtcToBtcSwapLimitsAndFees?.$2;
      }
    } else {
      if (fromWallet?.isLiquid == false && toWallet?.isLiquid == true) {
        return btcToLbtcSwapLimitsAndFees?.$2;
      } else if (fromWallet?.isLiquid == true && toWallet?.isLiquid == false) {
        return lbtcToBtcSwapLimitsAndFees?.$2;
      }
    }
    return null;
  }

  int getSwapFeesSat(int fromAmountSat) {
    final fees = swapFees;
    return fees?.totalFees(fromAmountSat) ?? 0;
  }

  int get inputAmountSat {
    if (amount.isEmpty) return 0;
    if (bitcoinUnit == BitcoinUnit.sats) {
      return int.tryParse(amount) ?? 0;
    } else {
      return ConvertAmount.btcToSats(double.tryParse(amount) ?? 0);
    }
  }

  String get formattedInputAmount {
    if (amount.isEmpty) return '0';
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(inputAmountSat);
    } else {
      return FormatAmount.btc(ConvertAmount.satsToBtc(inputAmountSat));
    }
  }

  int? get absoluteFees {
    if (fromWallet?.isLiquid == true) {
      return liquidAbsoluteFeesSat;
    } else {
      return bitcoinAbsoluteFeesSat;
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
}
