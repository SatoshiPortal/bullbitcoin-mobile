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
  }) = _TransferState;
  const TransferState._();

  String get displayToCurrencyCode {
    return '${toWallet?.isLiquid ?? false ? 'L-' : ''}${bitcoinUnit.code}';
  }

  String get displayFromCurrencyCode {
    return '${fromWallet?.isLiquid ?? false ? 'L-' : ''}${bitcoinUnit.code}';
  }

  SwapLimits? get swapLimits {
    if (fromWallet?.isLiquid == false && toWallet?.isLiquid == true) {
      return btcToLbtcSwapLimitsAndFees?.$1;
    } else if (fromWallet?.isLiquid == true && toWallet?.isLiquid == false) {
      return lbtcToBtcSwapLimitsAndFees?.$1;
    }
    return null;
  }

  int getSwapFeesSat(int fromAmountSat) {
    if (fromWallet?.isLiquid == false && toWallet?.isLiquid == true) {
      final fees = btcToLbtcSwapLimitsAndFees?.$2;
      return fees?.totalFees(fromAmountSat) ?? 0;
    } else if (fromWallet?.isLiquid == true && toWallet?.isLiquid == false) {
      final fees = lbtcToBtcSwapLimitsAndFees?.$2;
      return fees?.totalFees(fromAmountSat) ?? 0;
    }
    return 0;
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
