// ignore_for_file: unused_field

import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_paid_chain_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/swap/presentation/swap_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapCubit extends Cubit<SwapState> {
  SwapCubit({
    required GetSettingsUsecase getSettingsUsecase,
    required ConvertSatsToCurrencyAmountUsecase
    convertSatsToCurrencyAmountUsecase,
    required GetNetworkFeesUsecase getNetworkFeesUsecase,
    required GetWalletUtxosUsecase getWalletUtxosUsecase,
    required GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase,
    required PrepareBitcoinSendUsecase prepareBitcoinSendUsecase,
    required PrepareLiquidSendUsecase prepareLiquidSendUsecase,
    required GetWalletsUsecase getWalletsUsecase,
    required GetWalletUsecase getWalletUsecase,
    required GetSwapLimitsUsecase getSwapLimitsUsecase,
    required WatchSwapUsecase watchSwapUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
    required SignBitcoinTxUsecase signBitcoinTxUsecase,
    required SignLiquidTxUsecase signLiquidTxUsecase,
    required BroadcastBitcoinTransactionUsecase broadcastBitcoinTxUsecase,
    required BroadcastLiquidTransactionUsecase broadcastLiquidTxUsecase,
    required CalculateBitcoinAbsoluteFeesUsecase
    calculateBitcoinAbsoluteFeesUsecase,
    required CalculateLiquidAbsoluteFeesUsecase
    calculateLiquidAbsoluteFeesUsecase,
    required CreateChainSwapUsecase createChainSwapUsecase,
    required UpdatePaidChainSwapUsecase updatePaidChainSwapUsecase,
  }) : _getSettingsUsecase = getSettingsUsecase,
       _convertSatsToCurrencyAmountUsecase = convertSatsToCurrencyAmountUsecase,
       _getAvailableCurrenciesUsecase = getAvailableCurrenciesUsecase,
       _getNetworkFeesUsecase = getNetworkFeesUsecase,
       _getWalletUtxosUsecase = getWalletUtxosUsecase,
       _prepareBitcoinSendUsecase = prepareBitcoinSendUsecase,
       _prepareLiquidSendUsecase = prepareLiquidSendUsecase,
       _signLiquidTxUsecase = signLiquidTxUsecase,
       _signBitcoinTxUsecase = signBitcoinTxUsecase,
       _broadcastLiquidTxUsecase = broadcastLiquidTxUsecase,
       _broadcastBitcoinTxUsecase = broadcastBitcoinTxUsecase,
       _getWalletsUsecase = getWalletsUsecase,
       _getWalletUsecase = getWalletUsecase,
       _getSwapLimitsUsecase = getSwapLimitsUsecase,
       _watchSwapUsecase = watchSwapUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       _calculateBitcoinAbsoluteFeesUsecase =
           calculateBitcoinAbsoluteFeesUsecase,
       _calculateLiquidAbsoluteFeesUsecase = calculateLiquidAbsoluteFeesUsecase,
       _createChainSwapUsecase = createChainSwapUsecase,
       _updatePaidChainSwapUsecase = updatePaidChainSwapUsecase,
       super(const SwapState());

  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetWalletUsecase _getWalletUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final CreateChainSwapUsecase _createChainSwapUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTxUsecase;
  final GetSwapLimitsUsecase _getSwapLimitsUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;

  final WatchSwapUsecase _watchSwapUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final UpdatePaidChainSwapUsecase _updatePaidChainSwapUsecase;

  StreamSubscription<Swap>? _swapSubscription;
  StreamSubscription<Wallet>? _selectedWalletSyncingSubscription;

  @override
  Future<void> close() async {
    await Future.wait([
      _swapSubscription?.cancel() ?? Future.value(),
      _selectedWalletSyncingSubscription?.cancel() ?? Future.value(),
    ]);
    return super.close();
  }

  void clearAllExceptions() {
    emit(
      state.copyWith(
        insufficientBalanceException: null,
        swapCreationException: null,
        swapLimitsException: null,
        invalidBitcoinStringException: null,
        buildTransactionException: null,
        confirmTransactionException: null,
      ),
    );
  }

  Future<void> sendMaxClicked() async {
    try {
      if (state.loadingWallets) return;

      clearAllExceptions();
      final fromWallet = state.fromWallet;
      if (fromWallet == null) return;

      SwapLimits? swapLimits;

      if (state.selectedFeeList == null) {
        await loadFees();
      }

      final networkFee = state.selectedFeeList!.fastest;

      // Create a dummy drain transaction to calculate the absolute fees
      int absoluteFees;
      if (state.fromWalletNetwork == WalletNetwork.bitcoin) {
        if (state.fromWalletNetwork == WalletNetwork.bitcoin) {
          if (state.btcToLbtcSwapLimitsAndFees == null) {
            await loadSwapLimits();
          }
          swapLimits = state.btcToLbtcSwapLimitsAndFees!.$1;
        }
        // we cannot use a wallet address for this
        // the swap script address is larger than a wallet single sig (by ~12 vb)
        // this leads to a fee estimation error by 1 sat
        // additionally, we never sign this transaction
        const String dummySwapAddress =
            "bc1p0e9sutev5p0whwkdqdzy6gw03m6g66zuullc4erh80u7qezneskq9pj5n4";

        final dummyDrainTxInfo = await _prepareBitcoinSendUsecase.execute(
          walletId: fromWallet.id,
          address: dummySwapAddress,
          networkFee: networkFee,
          drain: true,
        );

        absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: dummyDrainTxInfo.unsignedPsbt,
          feeRate: networkFee.value as double,
        );

        log.info("Absolute fees: $absoluteFees");
        emit(state.copyWith(bitcoinAbsoluteFees: absoluteFees));
      } else {
        if (state.lbtcToBtcSwapLimitsAndFees == null) {
          await loadSwapLimits();
        }
        swapLimits = state.lbtcToBtcSwapLimitsAndFees!.$1;

        // we cannot use a wallet address for this
        // the swap script address is larger than a wallet single sig (by ~12 vb)
        // this leads to a fee estimation error by 1 sat
        // additionally, we never sign this transaction

        const String dummySwapAddress =
            "lq1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0we046p4uqlt24";
        final dummyPset = await _prepareLiquidSendUsecase.execute(
          walletId: fromWallet.id,
          address: dummySwapAddress,
          networkFee: networkFee,
          drain: true,
        );

        absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: dummyPset,
        );
        log.info("Absolute fees: $absoluteFees");

        emit(state.copyWith(liquidAbsoluteFees: absoluteFees));
      }

      final balance = fromWallet.balanceSat.toInt();
      final maxAmount = balance - absoluteFees;

      if (state.bitcoinUnit == BitcoinUnit.sats) {
        emit(state.copyWith(fromAmount: maxAmount.toString()));
        emit(state.copyWith(toAmount: state.calculateToAmount));
      } else {
        final validatedAmount = ConvertAmount.satsToBtc(maxAmount);
        emit(state.copyWith(fromAmount: validatedAmount.toString()));
        emit(state.copyWith(toAmount: state.calculateToAmount));
      }
      emit(state.copyWith(sendMax: true));
      // check swap limits
      if (swapLimits!.min > maxAmount) {
        emit(
          state.copyWith(
            swapLimitsException: SwapLimitsException(
              'Balance too low for minimum swap amount',
            ),
          ),
        );
        return;
      }
      if (swapLimits.max < maxAmount) {
        emit(
          state.copyWith(
            swapLimitsException: SwapLimitsException(
              'Amount exceeds maximum swap amount',
            ),
          ),
        );
        return;
      }
      return;
    } catch (e) {
      emit(
        state.copyWith(
          buildTransactionException: BuildTransactionException(e.toString()),
        ),
      );
    }
  }

  Future<void> init() async {
    emit(state.copyWith(loadingWallets: true));

    final wallets = await _getWalletsUsecase.execute();

    final liquidWallets = wallets.where((w) => w.isLiquid).toList();
    final bitcoinWallets =
        wallets.where((w) => !w.isLiquid && w.signsLocally).toList();
    final defaultBitcoinWallet = bitcoinWallets.firstWhere(
      (w) => w.isDefault,
      orElse: () => bitcoinWallets.first,
    );

    final settings = await _getSettingsUsecase.execute();

    final bitcoinUnit = settings.bitcoinUnit;
    emit(
      state.copyWith(
        fromWalletNetwork: WalletNetwork.liquid,
        toWalletNetwork: WalletNetwork.bitcoin,
        fromWalletId: liquidWallets.first.id,
        toWalletId: defaultBitcoinWallet.id,
        bitcoinUnit: bitcoinUnit,
        selectedFromCurrencyCode: bitcoinUnit.code,
        selectedToCurrencyCode: bitcoinUnit.code,
      ),
    );

    final currencies = await _getAvailableCurrenciesUsecase.execute();

    final selectedFiatCurrencyCode = settings.currencyCode;

    final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
      currencyCode: selectedFiatCurrencyCode,
    );

    await loadSwapLimits();

    emit(
      state.copyWith(
        fromWallets: liquidWallets,
        toWallets: bitcoinWallets,
        loadingWallets: false,
        fiatCurrencyCodes: currencies,
        fiatCurrencyCode: selectedFiatCurrencyCode,

        exchangeRate: exchangeRate,
      ),
    );
  }

  Future<void> loadSwapLimits() async {
    try {
      final settings = await _getSettingsUsecase.execute();
      final isTestnet = settings.environment == Environment.testnet;
      final lbtcToBtcswapLimits = await _getSwapLimitsUsecase.execute(
        type: SwapType.liquidToBitcoin,
        isTestnet: isTestnet,
      );
      emit(state.copyWith(lbtcToBtcSwapLimitsAndFees: lbtcToBtcswapLimits));
      final btcToLbtcSwapLimits = await _getSwapLimitsUsecase.execute(
        type: SwapType.bitcoinToLiquid,
        isTestnet: isTestnet,
        updateLimitsAndFees: false, // chain fees are already updated
      );
      emit(state.copyWith(btcToLbtcSwapLimitsAndFees: btcToLbtcSwapLimits));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> loadFees() async {
    if (state.fromWallet == null && state.toWallet == null) return;
    try {
      final fromNetworkFees = await _getNetworkFeesUsecase.execute(
        isLiquid: state.fromWallet!.network.isLiquid,
      );
      final toNetworkFees = await _getNetworkFeesUsecase.execute(
        isLiquid: state.toWallet!.network.isLiquid,
      );
      FeeOptions? bitcoinFeeList;
      FeeOptions? liquidFeeList;
      if (state.fromWallet!.network == Network.bitcoinMainnet ||
          state.fromWallet!.network == Network.bitcoinTestnet) {
        bitcoinFeeList = fromNetworkFees;
      } else if (state.fromWallet!.network == Network.liquidMainnet ||
          state.fromWallet!.network == Network.liquidTestnet) {
        liquidFeeList = toNetworkFees;
      }
      emit(
        state.copyWith(
          selectedFeeList: fromNetworkFees,
          bitcoinFeeList: bitcoinFeeList,
          liquidFeeList: liquidFeeList,
          customFee: null,
          selectedFee: fromNetworkFees.fastest,
          selectedFeeOption: FeeSelection.fastest,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void switchFromAndToWallets() {
    final newFromNetwork = state.toWalletNetwork;
    FeeOptions? newSelectedFeeList;
    NetworkFee? newSelectedFee;
    if (newFromNetwork == WalletNetwork.bitcoin) {
      newSelectedFeeList = state.bitcoinFeeList;
      newSelectedFee = state.bitcoinFeeList?.fastest;
    } else if (newFromNetwork == WalletNetwork.liquid) {
      newSelectedFeeList = state.liquidFeeList;
      newSelectedFee = state.liquidFeeList?.fastest;
    }
    emit(
      state.copyWith(
        fromWallets: state.toWallets,
        toWallets: state.fromWallets,
        fromWalletNetwork: state.toWalletNetwork,
        toWalletNetwork: state.fromWalletNetwork,
        selectedFromCurrencyCode: state.selectedToCurrencyCode,
        selectedToCurrencyCode: state.selectedFromCurrencyCode,
        fromWalletId: state.toWalletId,
        toWalletId: state.fromWalletId,
        selectedFeeList: newSelectedFeeList,
        selectedFee: newSelectedFee,
      ),
    );
  }

  void updateSelectedFromWallet(String walletId) {
    emit(state.copyWith(fromWalletId: walletId));
  }

  void updateSelectedToWallet(String walletId) {
    emit(state.copyWith(toWalletId: walletId));
  }

  void backClicked() {
    if (state.step == SwapPageStep.amount) {
      emit(state.copyWith(step: SwapPageStep.amount));
    } else if (state.step == SwapPageStep.confirm) {
      emit(state.copyWith(step: SwapPageStep.amount));
    }
  }

  Future<void> getExchangeRate({String? currencyCode}) async {
    final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
      currencyCode: currencyCode ?? state.fiatCurrencyCode,
    );

    emit(state.copyWith(exchangeRate: exchangeRate));
  }

  void amountChanged(String amount) {
    try {
      clearAllExceptions();
      emit(state.copyWith(sendMax: false));

      String validatedAmount;
      if (amount.isEmpty) {
        validatedAmount = amount;
      } else if (state.isInputAmountFiat) {
        final amountFiat = double.tryParse(amount);
        final isDecimalPoint = amount == '.';
        validatedAmount =
            amountFiat == null && !isDecimalPoint ? state.fromAmount : amount;
      } else if (state.bitcoinUnit == BitcoinUnit.sats) {
        final satoshis = BigInt.tryParse(amount);
        final hasDecimals = amount.contains('.');
        validatedAmount =
            satoshis == null || hasDecimals ? state.fromAmount : amount;
      } else {
        final amountBtc = double.tryParse(amount);
        final decimals =
            amount.contains('.') ? amount.split('.').last.length : 0;
        final isDecimalPoint = amount == '.';
        validatedAmount =
            (amountBtc == null && !isDecimalPoint) ||
                    decimals > BitcoinUnit.btc.decimals
                ? state.fromAmount
                : amount;
      }

      emit(state.copyWith(fromAmount: validatedAmount));
      emit(state.copyWith(toAmount: state.calculateToAmount));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> currencyCodeChanged(String currencyCode) async {
    if (currencyCode == BitcoinUnit.btc.code ||
        currencyCode == BitcoinUnit.sats.code) {
      emit(
        state.copyWith(
          bitcoinUnit: BitcoinUnit.fromCode(currencyCode),
          selectedFromCurrencyCode: currencyCode,
          selectedToCurrencyCode: currencyCode,
          fiatCurrencyCode: 'CAD',
          toAmount: '',
          fromAmount: '',
        ),
      );
      return;
    }
    await getExchangeRate(currencyCode: currencyCode);
    emit(
      state.copyWith(
        fiatCurrencyCode: currencyCode,
        selectedFromCurrencyCode: currencyCode,
        selectedToCurrencyCode: currencyCode,
        toAmount: '',
        fromAmount: '',
      ),
    );
    // await updateFiatApproximatedAmount();
  }

  Future<void> continueWithAmountsClicked() async {
    try {
      clearAllExceptions();
      emit(state.copyWith(amountConfirmedClicked: true));

      // Validate swap limits first
      if (state.swapAmountBelowLimit) {
        emit(
          state.copyWith(
            swapLimitsException: SwapLimitsException(
              'Amount is below minimum swap amount: ${state.swapLimits?.min} sats',
            ),
            amountConfirmedClicked: false,
          ),
        );
        return;
      }

      if (state.swapAmountAboveLimit) {
        emit(
          state.copyWith(
            swapLimitsException: SwapLimitsException(
              'Amount exceeds maximum swap amount: ${state.swapLimits?.max} sats',
            ),
            amountConfirmedClicked: false,
          ),
        );
        return;
      }

      final bitcoinWalletId =
          state.fromWalletNetwork == WalletNetwork.bitcoin
              ? state.fromWalletId
              : state.toWalletId;

      final liquidWalletId =
          state.fromWalletNetwork == WalletNetwork.liquid
              ? state.fromWalletId
              : state.toWalletId;
      final swapType =
          state.fromWalletNetwork == WalletNetwork.bitcoin
              ? SwapType.bitcoinToLiquid
              : SwapType.liquidToBitcoin;
      emit(state.copyWith(creatingSwap: true));
      final swap = await _createChainSwapUsecase.execute(
        bitcoinWalletId: bitcoinWalletId!,
        liquidWalletId: liquidWalletId!,
        type: swapType,
        amountSat: state.fromAmountSat,
      );

      _watchChainSwap(swap.id);
      await loadFees();
      emit(state.copyWith(amountConfirmedClicked: false));
      await Future.delayed(const Duration(milliseconds: 1000));
      emit(
        state.copyWith(
          step: SwapPageStep.confirm,
          swap: swap,
          creatingSwap: false,
        ),
      );
      await buildAndSignOnchainTransaction();
    } catch (e) {
      emit(
        state.copyWith(
          creatingSwap: false,
          swapCreationException: SwapCreationException(e.toString()),
          amountConfirmedClicked: false,
        ),
      );
    }
  }

  Future<void> buildAndSignOnchainTransaction() async {
    try {
      final swap = state.swap;
      if (swap == null) return;
      emit(state.copyWith(buildingTransaction: true));

      final bitcoinWalletId =
          state.fromWalletNetwork == WalletNetwork.bitcoin
              ? state.fromWalletId
              : state.toWalletId;
      final liquidWalletId =
          state.fromWalletNetwork == WalletNetwork.liquid
              ? state.fromWalletId
              : state.toWalletId;

      if (state.fromWalletNetwork == WalletNetwork.bitcoin) {
        final unsignedPsbtAndTxSize = await _prepareBitcoinSendUsecase.execute(
          walletId: bitcoinWalletId!,
          address: swap.paymentAddress,
          amountSat: swap.paymentAmount,
          networkFee:
              state.bitcoinAbsoluteFees != null
                  ? NetworkFee.absolute(state.bitcoinAbsoluteFees!)
                  : state.selectedFeeList!.fastest,
        );
        emit(
          state.copyWith(buildingTransaction: false, signingTransaction: true),
        );

        final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
          walletId: bitcoinWalletId,
          psbt: unsignedPsbtAndTxSize.unsignedPsbt,
        );
        final bitcoinAbsoluteFees = await _calculateBitcoinAbsoluteFeesUsecase
            .execute(
              psbt: signedPsbtAndTxSize.signedPsbt,
              feeRate: state.selectedFeeList!.fastest.value as double,
            );

        emit(
          state.copyWith(
            signingTransaction: false,
            bitcoinAbsoluteFees: bitcoinAbsoluteFees,
            signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
          ),
        );
      } else {
        emit(state.copyWith(buildingTransaction: true));

        final psbt = await _prepareLiquidSendUsecase.execute(
          walletId: liquidWalletId!,
          address: swap.paymentAddress,
          amountSat: state.sendMax ? null : swap.paymentAmount,
          networkFee: state.selectedFeeList!.fastest,
          drain: state.sendMax,
        );
        final signedPsbt = await _signLiquidTxUsecase.execute(
          walletId: liquidWalletId,
          pset: psbt,
        );
        final absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: signedPsbt,
        );
        emit(
          state.copyWith(
            buildingTransaction: false,
            signingTransaction: true,
            liquidAbsoluteFees: absoluteFees,
          ),
        );

        emit(
          state.copyWith(signingTransaction: false, signedLiquidTx: signedPsbt),
        );
      }
    } catch (e) {
      if (e is PrepareBitcoinSendException) {
        emit(
          state.copyWith(
            confirmTransactionException: ConfirmTransactionException(e.message),
          ),
        );
        return;
      }
      if (e is CalculateBitcoinAbsoluteFeesException) {
        emit(
          state.copyWith(
            confirmTransactionException: ConfirmTransactionException(e.message),
          ),
        );
        return;
      }
      if (e is PrepareLiquidSendException) {
        emit(
          state.copyWith(
            confirmTransactionException: ConfirmTransactionException(e.message),
          ),
        );
        return;
      }
      if (e is CalculateLiquidAbsoluteFeesException) {
        emit(
          state.copyWith(
            confirmTransactionException: ConfirmTransactionException(e.message),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          confirmTransactionException: ConfirmTransactionException(
            e.toString(),
          ),
        ),
      );
      emit(
        state.copyWith(
          buildingTransaction: false,
          signingTransaction: false,
          broadcastingTransaction: false,
        ),
      );
    }
  }

  Future<void> confirmSwapClicked() async {
    try {
      final swap = state.swap;
      if (swap == null) return;
      emit(state.copyWith(buildingTransaction: true));

      final settings = await _getSettingsUsecase.execute();
      final isTestnet = settings.environment == Environment.testnet;

      if (state.fromWalletNetwork == WalletNetwork.bitcoin) {
        if (state.signedBitcoinPsbt == null) {
          emit(state.copyWith(buildingTransaction: false));
          return;
          // TODO: add a proper error in the state
        }
        final txid = await _broadcastBitcoinTxUsecase.execute(
          state.signedBitcoinPsbt!,
          isPsbt: true,
        );
        await _updatePaidChainSwapUsecase.execute(
          txid: txid,
          swapId: swap.id,
          network: Network.fromEnvironment(
            isTestnet: isTestnet,
            isLiquid: false,
          ),
          absoluteFees:
              0, // TODO (ishi): removed until server fees are implemented
        );
      } else {
        if (state.signedLiquidTx == null) {
          emit(state.copyWith(buildingTransaction: false));
          return;
          // TODO: add a proper error in the state
        }

        final txid = await _broadcastLiquidTxUsecase.execute(
          state.signedLiquidTx!,
        );
        await _updatePaidChainSwapUsecase.execute(
          txid: txid,
          swapId: swap.id,
          network: Network.fromEnvironment(
            isTestnet: isTestnet,
            isLiquid: true,
          ),
          absoluteFees:
              0, // TODO (ishi): removed until server fees are implemented
        );
      }
      emit(
        state.copyWith(
          step: SwapPageStep.progress,
          broadcastingTransaction: false,
        ),
      );
    } catch (e) {
      if (e is PrepareBitcoinSendException) {
        emit(
          state.copyWith(
            confirmTransactionException: ConfirmTransactionException(
              'Could not build transaction. Likely due to insufficient funds to cover fees and amount.',
            ),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          confirmTransactionException: ConfirmTransactionException(
            e.toString(),
          ),
        ),
      );
      emit(
        state.copyWith(
          buildingTransaction: false,
          signingTransaction: false,
          broadcastingTransaction: false,
        ),
      );
    }
  }

  // ignore: unused_element
  void _watchChainSwap(String swapId) {
    // Cancel the previous subscription if it exists
    _swapSubscription?.cancel();
    _swapSubscription = _watchSwapUsecase.execute(swapId).listen((updatedSwap) {
      log.info(
        '[SwapCubit] Watched swap ${updatedSwap.id} updated: ${updatedSwap.status}',
      );
      if (updatedSwap is ChainSwap) {
        emit(state.copyWith(swap: updatedSwap));
        if (updatedSwap.status == SwapStatus.completed) {
          // Start syncing the wallet now that the swap is completed
          _getWalletUsecase.execute(state.fromWalletId!, sync: true);
          _getWalletUsecase.execute(state.toWalletId!, sync: true);

          emit(state.copyWith(step: SwapPageStep.success));
        }
      }
    });
  }
}
