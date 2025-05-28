import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit({
    Wallet? wallet,
    required SelectBestWalletUsecase bestWalletUsecase,
    required DetectBitcoinStringUsecase detectBitcoinStringUsecase,
    required GetSettingsUsecase getSettingsUsecase,
    required ConvertSatsToCurrencyAmountUsecase
    convertSatsToCurrencyAmountUsecase,
    required GetNetworkFeesUsecase getNetworkFeesUsecase,
    required GetWalletUtxosUsecase getWalletUtxosUsecase,
    required GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase,
    required PrepareBitcoinSendUsecase prepareBitcoinSendUsecase,
    required PrepareLiquidSendUsecase prepareLiquidSendUsecase,
    required SendWithPayjoinUsecase sendWithPayjoinUsecase,
    required GetWalletsUsecase getWalletsUsecase,
    required GetWalletUsecase getWalletUsecase,
    required CreateSendSwapUsecase createSendSwapUsecase,
    required UpdatePaidSendSwapUsecase updatePaidSendSwapUsecase,
    required GetSwapLimitsUsecase getSwapLimitsUsecase,
    required WatchSwapUsecase watchSwapUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
    required DecodeInvoiceUsecase decodeInvoiceUsecase,
    required SignBitcoinTxUsecase signBitcoinTxUsecase,
    required SignLiquidTxUsecase signLiquidTxUsecase,
    required BroadcastBitcoinTransactionUsecase broadcastBitcoinTxUsecase,
    required BroadcastLiquidTransactionUsecase broadcastLiquidTxUsecase,
    required CalculateLiquidAbsoluteFeesUsecase
    calculateLiquidAbsoluteFeesUsecase,
    required CreateChainSwapToExternalUsecase createChainSwapToExternalUsecase,
    required WatchWalletTransactionByTxIdUsecase
    watchWalletTransactionByTxIdUsecase,
  }) : _wallet = wallet,
       _getSettingsUsecase = getSettingsUsecase,
       _convertSatsToCurrencyAmountUsecase = convertSatsToCurrencyAmountUsecase,
       _getAvailableCurrenciesUsecase = getAvailableCurrenciesUsecase,
       _bestWalletUsecase = bestWalletUsecase,
       _detectBitcoinStringUsecase = detectBitcoinStringUsecase,
       _getNetworkFeesUsecase = getNetworkFeesUsecase,
       _getWalletUtxosUsecase = getWalletUtxosUsecase,
       _prepareBitcoinSendUsecase = prepareBitcoinSendUsecase,
       _prepareLiquidSendUsecase = prepareLiquidSendUsecase,
       _sendWithPayjoinUsecase = sendWithPayjoinUsecase,
       _signLiquidTxUsecase = signLiquidTxUsecase,
       _signBitcoinTxUsecase = signBitcoinTxUsecase,
       _broadcastLiquidTxUsecase = broadcastLiquidTxUsecase,
       _broadcastBitcoinTxUsecase = broadcastBitcoinTxUsecase,
       _getWalletsUsecase = getWalletsUsecase,
       _getWalletUsecase = getWalletUsecase,
       _createSendSwapUsecase = createSendSwapUsecase,
       _updatePaidSendSwapUsecase = updatePaidSendSwapUsecase,
       _getSwapLimitsUsecase = getSwapLimitsUsecase,
       _watchSwapUsecase = watchSwapUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       _decodeInvoiceUsecase = decodeInvoiceUsecase,
       _calculateLiquidAbsoluteFeesUsecase = calculateLiquidAbsoluteFeesUsecase,
       _createChainSwapToExternalUsecase = createChainSwapToExternalUsecase,
       _watchWalletTransactionByTxIdUsecase =
           watchWalletTransactionByTxIdUsecase,
       super(const SendState());

  // ignore: unused_field
  final Wallet? _wallet;
  final SelectBestWalletUsecase _bestWalletUsecase;
  final DetectBitcoinStringUsecase _detectBitcoinStringUsecase;
  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetWalletUsecase _getWalletUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final CreateSendSwapUsecase _createSendSwapUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTxUsecase;
  final SendWithPayjoinUsecase _sendWithPayjoinUsecase;
  final UpdatePaidSendSwapUsecase _updatePaidSendSwapUsecase;
  final GetSwapLimitsUsecase _getSwapLimitsUsecase;
  final DecodeInvoiceUsecase _decodeInvoiceUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;

  final WatchSwapUsecase _watchSwapUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final WatchWalletTransactionByTxIdUsecase
  _watchWalletTransactionByTxIdUsecase;

  final CreateChainSwapToExternalUsecase _createChainSwapToExternalUsecase;

  StreamSubscription<Swap>? _swapSubscription;
  StreamSubscription<Wallet>? _selectedWalletSyncingSubscription;
  StreamSubscription<WalletTransaction>? _txSubscription;

  @override
  Future<void> close() async {
    await (
      _swapSubscription?.cancel() ?? Future.value(),
      _selectedWalletSyncingSubscription?.cancel() ?? Future.value(),
      _txSubscription?.cancel() ?? Future.value(),
    ).wait;
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

  void backClicked() {
    if (state.step == SendStep.address) {
      emit(state.copyWith(step: SendStep.address));
    } else if (state.step == SendStep.amount) {
      emit(state.copyWith(step: SendStep.address));
    } else if (state.step == SendStep.confirm) {
      emit(state.copyWith(step: SendStep.amount));
    }
  }

  Future<void> loadWalletWithRatesAndFees() async {
    try {
      final wallets = await _getWalletsUsecase.execute();
      emit(
        state.copyWith(wallets: wallets.where((w) => !w.isWatchOnly).toList()),
      );
      await getCurrencies();
      await getExchangeRate();
      await loadFees();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Called when a payment request is detected directly from the scanner
  Future<void> onScannedPaymentRequest((String, PaymentRequest?) data) async {
    clearAllExceptions();
    emit(state.copyWith(paymentRequestData: data));
    await continueOnAddressConfirmed();
  }

  /// Called when text is pasted or entered manually
  Future<void> onPastedText(String text) async {
    try {
      clearAllExceptions();
      final sanitizedText = text.trim().replaceAll(
        RegExp(r'^["\"]+|["\"]+$'),
        '',
      );
      final paymentRequest = await _detectBitcoinStringUsecase.execute(
        data: sanitizedText,
      );
      emit(state.copyWith(paymentRequestData: (sanitizedText, paymentRequest)));
    } catch (e) {
      emit(
        state.copyWith(
          invalidBitcoinStringException: InvalidBitcoinStringException(),
        ),
      );
    }
  }

  Future<void> continueOnAddressConfirmed() async {
    try {
      clearAllExceptions();
      emit(state.copyWith(loadingBestWallet: true, invoiceHasMrh: false));

      if (!state.hasValidPaymentRequest) {
        emit(
          state.copyWith(
            loadingBestWallet: false,
            invalidBitcoinStringException: InvalidBitcoinStringException(),
          ),
        );
        return;
      }

      if (state.paymentRequest!.isBolt11) {
        final paymentRequest = state.paymentRequest! as Bolt11PaymentRequest;
        final invoice = await _decodeInvoiceUsecase.execute(
          invoice: paymentRequest.invoice,
          isTestnet: state.paymentRequest!.isTestnet,
        );
        if (invoice.magicBip21 != null) {
          final updatedRequest = await _detectBitcoinStringUsecase.execute(
            data: invoice.magicBip21!,
          );
          emit(
            state.copyWith(
              paymentRequestData: (invoice.magicBip21!, updatedRequest),
              invoiceHasMrh: true,
            ),
          );
        }
      }

      // Use the preselected wallet passed in the constructor if available,
      //  otherwise use the best wallet for the payment request and amount
      final wallet =
          _wallet ??
          _bestWalletUsecase.execute(
            wallets: state.wallets,
            request: state.paymentRequest!,
            amountSat: state.paymentRequest!.amountSat,
          );

      // Listen to the wallet syncing status to update the wallet balance and its utxos
      // Do we need to do this? The wallet selected may change in the amount page
      await _selectedWalletSyncingSubscription?.cancel();
      _selectedWalletSyncingSubscription = _watchFinishedWalletSyncsUsecase
          .execute(walletId: wallet.id)
          .listen((wallet) async {
            emit(state.copyWith(selectedWallet: wallet));
            await loadUtxos();
          });

      final sendType = SendType.from(state.paymentRequest!);

      emit(state.copyWith(selectedWallet: wallet, sendType: sendType));

      await loadSwapLimits();
      final swapType =
          wallet.isLiquid
              ? SwapType.liquidToLightning
              : SwapType.bitcoinToLightning;

      // for bolt12 or lnaddress we need to redirect to the amount page and only create a swap after amount is set
      if (state.invoiceHasMrh) {
        if (!await hasBalance()) {
          emit(
            state.copyWith(
              insufficientBalanceException: InsufficientBalanceException(),
              creatingSwap: false,
              loadingBestWallet: false,
            ),
          );
          return;
        }
        //
        await loadFees();
        await loadUtxos();
        emit(
          state.copyWith(confirmedAmountSat: state.paymentRequest!.amountSat),
        );
        await createTransaction();
        emit(
          state.copyWith(
            step: SendStep.confirm,
            confirmedAmountSat: state.paymentRequest!.amountSat,
          ),
        );

        return;
      }
      if (state.paymentRequest!.isBolt11) {
        emit(state.copyWith(creatingSwap: true));
        if (!await hasBalance()) {
          emit(
            state.copyWith(
              insufficientBalanceException: InsufficientBalanceException(),
              creatingSwap: false,
              loadingBestWallet: false,
            ),
          );
          return;
        }
        if (state.swapAmountBelowLimit) {
          if (!state.selectedWallet!.isLiquid) {
            emit(
              state.copyWith(
                creatingSwap: false,
                insufficientBalanceException: InsufficientBalanceException(
                  message:
                      'Not enough balance to pay this swap via Liquid and not within swap limits to pay via Bitcoin.',
                ),
                loadingBestWallet: false,
              ),
            );
            return;
          } else {
            emit(
              state.copyWith(
                creatingSwap: false,
                swapLimitsException: SwapLimitsException(
                  'Amount is below swap limits',
                ),
                loadingBestWallet: false,
              ),
            );
          }
          return;
        }
        if (state.swapAmountAboveLimit) {
          emit(
            state.copyWith(
              creatingSwap: false,
              swapLimitsException: SwapLimitsException(
                'Amount is above swap limits',
              ),
              loadingBestWallet: false,
            ),
          );
          return;
        }

        try {
          final paymentRequest = state.paymentRequest! as Bolt11PaymentRequest;
          final swap = await _createSendSwapUsecase.execute(
            walletId: wallet.id,
            type: swapType,
            invoice: paymentRequest.invoice,
          );
          await loadFees();
          await loadUtxos();
          emit(
            state.copyWith(
              step: SendStep.confirm,
              lightningSwap: swap,
              confirmedAmountSat: state.paymentRequest!.amountSat,
              creatingSwap: false,
            ),
          );
          await createTransaction();
          updateSwapLockupFees();
        } catch (e) {
          emit(
            state.copyWith(
              creatingSwap: false,
              swapCreationException: SwapCreationException(e.toString()),
              loadingBestWallet: false,
            ),
          );
          return;
        }
      }
      if (state.paymentRequest!.isBip21) {
        await loadFees();
        await loadUtxos();
        emit(
          state.copyWith(
            confirmedAmountSat: state.paymentRequest!.amountSat,
            step: SendStep.confirm,
            loadingBestWallet: false,
          ),
        );
        await createTransaction();

        return;
      } else {
        await loadFees();
        await loadUtxos();
        emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
        return;
      }
    } catch (e) {
      if (e is NotEnoughFundsException) {
        emit(
          state.copyWith(
            loadingBestWallet: false,
            insufficientBalanceException: InsufficientBalanceException(),
          ),
        );
      } else {
        emit(state.copyWith(error: e, loadingBestWallet: false));
      }
    }
  }

  void updateSwapLockupFees() {
    final absFees = state.absoluteFees;
    if (absFees == null) return;

    if (state.lightningSwap != null) {
      final swap = state.lightningSwap!;
      final updatedFees = swap.fees?.copyWith(lockupFee: absFees);
      emit(state.copyWith(lightningSwap: swap.copyWith(fees: updatedFees)));
      return;
    }
    if (state.chainSwap != null) {
      final swap = state.chainSwap!;
      final updatedFees = swap.fees?.copyWith(lockupFee: absFees);
      emit(state.copyWith(chainSwap: swap.copyWith(fees: updatedFees)));
      return;
    }
  }

  Future<void> loadSwapLimits() async {
    final paymentRequest = state.paymentRequest;
    final loadLnSwapLimits =
        paymentRequest?.isBolt11 == true || paymentRequest?.isLnAddress == true;
    if (loadLnSwapLimits) {
      final (
        (liquidSwapLimits, liquidSwapFees),
        (bitcoinSwapLimits, bitcoinSwapFees),
      ) = await (
            _getSwapLimitsUsecase.execute(
              isTestnet: state.selectedWallet!.network.isTestnet,
              type: SwapType.liquidToLightning,
            ),
            _getSwapLimitsUsecase.execute(
              isTestnet: state.selectedWallet!.network.isTestnet,
              type: SwapType.bitcoinToLightning,
            ),
          ).wait;
      emit(
        state.copyWith(
          liquidSwapLimits: liquidSwapLimits,
          liquidSwapFees: liquidSwapFees,
          bitcoinSwapLimits: bitcoinSwapLimits,
          bitcoinSwapFees: bitcoinSwapFees,
        ),
      );
    }
    if (state.requireChainSwap) {
      final (
        (liquidSwapLimits, liquidSwapFees),
        (bitcoinSwapLimits, bitcoinSwapFees),
      ) = await (
            _getSwapLimitsUsecase.execute(
              isTestnet: state.selectedWallet!.network.isTestnet,
              type: SwapType.liquidToBitcoin,
            ),
            _getSwapLimitsUsecase.execute(
              isTestnet: state.selectedWallet!.network.isTestnet,
              type: SwapType.bitcoinToLiquid,
            ),
          ).wait;
      emit(
        state.copyWith(
          liquidSwapLimits: liquidSwapLimits,
          liquidSwapFees: liquidSwapFees,
          bitcoinSwapLimits: bitcoinSwapLimits,
          bitcoinSwapFees: bitcoinSwapFees,
        ),
      );
    }
  }

  void toggleSwapLimitsForWallet() {
    if (state.selectedWallet == null) return;

    final walletNetwork = state.selectedWallet!.network;
    switch (walletNetwork) {
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        emit(
          state.copyWith(
            selectedSwapFees: state.bitcoinSwapFees,
            selectedSwapLimits: state.bitcoinSwapLimits,
          ),
        );
      case Network.liquidMainnet:
      case Network.liquidTestnet:
        emit(
          state.copyWith(
            selectedSwapFees: state.liquidSwapFees,
            selectedSwapLimits: state.liquidSwapLimits,
          ),
        );
    }
  }

  Future<bool> hasBalance() async {
    if (state.selectedWallet == null && state.paymentRequest == null) {
      return false;
    }
    final wallet = state.selectedWallet!;
    final paymentRequest = state.paymentRequest;
    switch (paymentRequest) {
      case Bolt11PaymentRequest _:
        // final swapLimits = state.swapLimits!.;
        final invoice = await _decodeInvoiceUsecase.execute(
          invoice: state.addressOrInvoice,
          isTestnet: wallet.network.isTestnet,
        );
        final invoiceAmount = invoice.sats;
        final feeEstimate =
            state.selectedSwapFees?.totalFees(invoiceAmount) ?? 0;
        final totalPayable = invoiceAmount + feeEstimate;
        return wallet.balanceSat.toInt() > totalPayable;

      case LnAddressPaymentRequest _:
        final invoiceAmount = state.inputAmountSat;
        final feeEstimate =
            state.selectedSwapFees?.totalFees(invoiceAmount) ?? 0;
        final totalPayable = invoiceAmount + feeEstimate;
        return wallet.balanceSat.toInt() > totalPayable;

      default:
        // does not consider fees yet
        // we will only consider fee estimate at this stage
        return wallet.balanceSat.toInt() >=
            (state.inputAmountSat + (state.absoluteFees ?? 0));
    }
  }

  Future<void> getCurrencies() async {
    final settings = await _getSettingsUsecase.execute();

    final (exchangeRate, fiatCurrencies) =
        await (
          _convertSatsToCurrencyAmountUsecase.execute(),
          _getAvailableCurrenciesUsecase.execute(),
        ).wait;

    final bitcoinUnit = settings.bitcoinUnit;
    final fiatCurrency = settings.currencyCode;

    emit(
      state.copyWith(
        fiatCurrencyCodes: fiatCurrencies,
        fiatCurrencyCode: fiatCurrency,
        exchangeRate: exchangeRate,
        bitcoinUnit: bitcoinUnit,
        inputAmountCurrencyCode: bitcoinUnit.code,
      ),
    );
  }

  Future<void> amountChanged(String amount) async {
    try {
      clearAllExceptions();
      String validatedAmount;

      if (amount.isEmpty) {
        validatedAmount = amount;
      } else if (state.isInputAmountFiat) {
        final amountFiat = double.tryParse(amount);
        final isDecimalPoint = amount == '.';

        validatedAmount =
            amountFiat == null && !isDecimalPoint ? state.amount : amount;
      } else if (state.inputAmountCurrencyCode == BitcoinUnit.sats.code) {
        // If the amount is in sats, make sure it is a valid BigInt and do not
        //  allow a decimal point.
        final amountSats = BigInt.tryParse(amount);
        final hasDecimals = amount.contains('.');

        validatedAmount =
            amountSats == null ||
                    hasDecimals ||
                    amountSats > ConversionConstants.maxSatsAmount
                ? state.amount
                : amountSats.toString();
      } else {
        // If the amount is in BTC, make sure it is a valid double and
        //  do not allow more than 8 decimal places.
        final amountBtc = double.tryParse(amount);
        final decimals = amount.split('.').last.length;
        final isDecimalPoint = amount == '.';

        validatedAmount =
            (amountBtc == null && !isDecimalPoint) ||
                    decimals > BitcoinUnit.btc.decimals ||
                    (amountBtc != null &&
                        amountBtc >
                            ConversionConstants.maxBitcoinAmount.toDouble())
                ? state.amount
                : amount;
      }

      emit(state.copyWith(amount: validatedAmount, sendMax: false));
      await updateBestWallet();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> onCurrencyChanged(String currencyCode) async {
    double exchangeRate = state.exchangeRate;
    String fiatCurrencyCode = state.fiatCurrencyCode;

    if (![BitcoinUnit.btc.code, BitcoinUnit.sats.code].contains(currencyCode)) {
      // If the currency is a fiat currency, retrieve the exchange rate and replace
      //  the current exchange rate and fiat currency code.
      fiatCurrencyCode = currencyCode;
      exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: currencyCode,
      );
    } else {
      // If the currency is a bitcoin unit, set the fiat currency and exchange
      //  rate back to the currency from the settings.
      final currencyValues = await Future.wait([
        _getSettingsUsecase.execute(),
        _convertSatsToCurrencyAmountUsecase.execute(),
      ]);

      fiatCurrencyCode = (currencyValues[0] as SettingsEntity).currencyCode;
      exchangeRate = currencyValues[1] as double;
    }

    emit(
      state.copyWith(
        inputAmountCurrencyCode: currencyCode,
        fiatCurrencyCode: fiatCurrencyCode,
        exchangeRate: exchangeRate,
        amount: '', // Clear the amount when changing the currency
      ),
    );
  }

  Future<void> updateBestWallet() async {
    try {
      // clearAllExceptions();
      if (state.paymentRequest == null || state.selectedWallet == null) return;
      final previousSelectedWallet = state.selectedWallet!;

      emit(state.copyWith(loadingBestWallet: true));

      // Use the preselected wallet passed in the constructor if available,
      //  otherwise use the best wallet for the payment request and amount
      final wallet =
          _wallet ??
          _bestWalletUsecase.execute(
            wallets: state.wallets,
            request: state.paymentRequest!,
            amountSat: state.inputAmountSat,
          );
      emit(
        state.copyWith(
          selectedWallet: wallet,
          loadingBestWallet: false,
          insufficientBalanceException: null,
        ),
      );

      if (state.selectedWallet!.id != previousSelectedWallet.id) {
        toggleSwapLimitsForWallet();
        await _selectedWalletSyncingSubscription?.cancel();
        _selectedWalletSyncingSubscription = _watchFinishedWalletSyncsUsecase
            .execute(walletId: wallet.id)
            .listen((wallet) async {
              emit(state.copyWith(selectedWallet: wallet));
              await loadFees();
              await loadUtxos();
            });
      }
    } catch (e) {
      emit(state.copyWith(loadingBestWallet: false));
    }
  }

  // Future<void> updateUpdatedWalletSyncSubscription(
  //   String previousSelectedWalletId,
  // ) async {
  //   try {
  //     if (state.selectedWallet!.id != previousSelectedWalletId) {
  //       toggleSwapLimitsForWallet();
  //       await _selectedWalletSyncingSubscription?.cancel();
  //       _selectedWalletSyncingSubscription = _watchFinishedWalletSyncsUsecase
  //           .execute(walletId: state.selectedWallet!.id)
  //           .listen((wallet) async {
  //             emit(state.copyWith(selectedWallet: wallet));
  //             await loadFees();
  //             await loadUtxos();
  //           });
  //     }
  //   } catch (e) {
  //     emit(state.copyWith(loadingBestWallet: false));
  //   }
  // }

  Future<void> onAmountConfirmed() async {
    clearAllExceptions();
    emit(
      state.copyWith(
        amountConfirmedClicked: true,
        confirmedAmountSat: state.inputAmountSat,
      ),
    );

    if (state.sendType == SendType.lightning) {
      final swapType =
          state.selectedWallet!.isLiquid
              ? SwapType.liquidToLightning
              : SwapType.bitcoinToLightning;

      if (state.swapAmountBelowLimit) {
        emit(
          state.copyWith(
            swapLimitsException: SwapLimitsException(
              'Amount below minimum swap limit: ${state.selectedSwapLimits!.min} sats',
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
              'Amount above maximum swap limit: ${state.selectedSwapLimits!.max} sats',
            ),
            amountConfirmedClicked: false,
          ),
        );
        return;
      }
      try {
        emit(state.copyWith(creatingSwap: true));

        final swap = await _createSendSwapUsecase.execute(
          walletId: state.selectedWallet!.id,
          type: swapType,
          lnAddress: state.addressOrInvoice,
          amountSat: state.confirmedAmountSat,
        );
        emit(
          state.copyWith(
            amountConfirmedClicked: false,
            step: SendStep.confirm,
            lightningSwap: swap,
            creatingSwap: false,
          ),
        );
        _watchSendSwap(swap.id);
        await createTransaction();
        updateSwapLockupFees();
      } catch (e) {
        emit(
          state.copyWith(
            creatingSwap: false,
            swapCreationException: SwapCreationException(e.toString()),
            amountConfirmedClicked: false,
            step: SendStep.amount,
          ),
        );
      }
      return;
    }
    final isChainSwap =
        (state.sendType == SendType.liquid &&
            !state.selectedWallet!.isLiquid) ||
        state.sendType == SendType.bitcoin && state.selectedWallet!.isLiquid;
    if (isChainSwap) {
      try {
        final swapType =
            state.selectedWallet!.isLiquid
                ? SwapType.liquidToBitcoin
                : SwapType.bitcoinToLiquid;
        toggleSwapLimitsForWallet();
        if (state.swapAmountBelowLimit) {
          emit(
            state.copyWith(
              swapLimitsException: SwapLimitsException(
                'Amount below minimum swap limit: ${state.selectedSwapLimits!.min} sats',
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
                'Amount above maximum swap limit: ${state.selectedSwapLimits!.max} sats',
              ),
              amountConfirmedClicked: false,
            ),
          );
          return;
        }
        emit(state.copyWith(creatingSwap: true));

        final swap = await _createChainSwapToExternalUsecase.execute(
          sendWalletId: state.selectedWallet!.id,
          receiveAddress: state.addressOrInvoice,
          type: swapType,
          amountSat: state.inputAmountSat,
        );
        _watchSendSwap(swap.id);

        emit(
          state.copyWith(
            amountConfirmedClicked: false,
            step: SendStep.confirm,
            chainSwap: swap,
            creatingSwap: false,
          ),
        );
        await createTransaction();
        updateSwapLockupFees();
      } catch (e) {
        emit(
          state.copyWith(
            creatingSwap: false,
            swapCreationException: SwapCreationException(e.toString()),
            amountConfirmedClicked: false,
          ),
        );
      }
    } else if (state.sendType == SendType.bitcoin ||
        state.sendType == SendType.liquid) {
      await createTransaction();
    }
    if (state.sendType == SendType.liquid ||
        state.sendType == SendType.bitcoin) {
      await createTransaction();
    }
    if (!await hasBalance()) {
      emit(
        state.copyWith(
          insufficientBalanceException: InsufficientBalanceException(
            message: 'Not enough funds to cover amount and fees',
          ),
          amountConfirmedClicked: false,
        ),
      );
      return;
    }
    if (state.buildTransactionException == null) {
      emit(
        state.copyWith(
          step: SendStep.confirm,
          confirmedAmountSat: state.inputAmountSat,
        ),
      );
    } else {
      emit(state.copyWith(amountConfirmedClicked: false));
    }
  }

  void onMaxPressed() {
    if (state.selectedWallet == null) return;

    String maxAmount = '';

    if (state.selectedUtxos.isNotEmpty) {
      // Todo: utxo.value should be non-null again when the frozen utxo stuff is fixed
      // then we can remove the fallback to BigInt.zero on utxo.value
      final totalSats = state.selectedUtxos.fold<BigInt>(
        BigInt.zero,
        (sum, utxo) => sum + (utxo.amountSat),
      );
      maxAmount = totalSats.toString();
    } else {
      maxAmount = state.selectedWallet!.balanceSat.toString();
    }
    if (state.bitcoinUnit == BitcoinUnit.btc) {
      final btcAmount = ConvertAmount.satsToBtc(
        state.selectedWallet!.balanceSat.toInt(),
      );
      maxAmount = btcAmount.toString();
    }
    emit(state.copyWith(amount: maxAmount, sendMax: true));
  }

  void noteChanged(String note) => emit(state.copyWith(label: note));

  Future<void> loadUtxos() async {
    if (state.selectedWallet == null) return;

    try {
      final utxos = await _getWalletUtxosUsecase.execute(
        walletId: state.selectedWallet!.id,
      );
      emit(state.copyWith(utxos: utxos));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void utxoSelected(WalletUtxo utxo) {
    final selectedUtxos = List.of(state.selectedUtxos);
    if (selectedUtxos.contains(utxo)) {
      selectedUtxos.remove(utxo);
    } else {
      selectedUtxos.add(utxo);
    }
    emit(state.copyWith(selectedUtxos: selectedUtxos));
  }

  void replaceByFeeChanged(bool replaceByFee) {
    emit(state.copyWith(replaceByFee: replaceByFee));
  }

  Future<void> loadFees() async {
    if (state.selectedWallet == null) return;
    try {
      final settings = await _getSettingsUsecase.execute();
      final environment = settings.environment;
      final bitcoinNetwork = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: false,
      );
      final liquidNetwork = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: true,
      );
      final bitcoinFees = await _getNetworkFeesUsecase.execute(
        network: bitcoinNetwork,
      );
      final liquidFees = await _getNetworkFeesUsecase.execute(
        network: liquidNetwork,
      );
      emit(
        state.copyWith(
          bitcoinFeesList: bitcoinFees,
          liquidFeesList: liquidFees,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void feeOptionSelected(FeeSelection feeSelection) {
    emit(state.copyWith(selectedFeeOption: feeSelection));
    updateSwapLockupFees();
  }

  void customFeesChanged(NetworkFee fee) {
    emit(
      state.copyWith(customFee: fee, selectedFeeOption: FeeSelection.custom),
    );
    updateSwapLockupFees();
  }

  Future<void> createTransaction() async {
    try {
      clearAllExceptions();
      emit(state.copyWith(buildingTransaction: true));
      final address =
          state.lightningSwap != null
              ? state.lightningSwap!.paymentAddress
              : state.paymentRequest != null &&
                  state.paymentRequest is Bip21PaymentRequest
              ? (state.paymentRequest! as Bip21PaymentRequest).address
              : (state.chainSwap != null)
              ? state.chainSwap!.paymentAddress
              : state.addressOrInvoice;
      final amount =
          state.lightningSwap != null
              ? state.lightningSwap!.paymentAmount
              : (state.chainSwap != null)
              ? state.chainSwap!.paymentAmount
              : state.confirmedAmountSat;
      // Fees can be selectedFee as it defaults to Fastest
      if (state.selectedWallet!.network.isLiquid) {
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: address,
          networkFee: state.selectedFee!,
          amountSat: amount,
          // ignore: avoid_bool_literals_in_conditional_expressions
          drain: state.lightningSwap != null ? false : state.sendMax,
        );
        final absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
          walletId: state.selectedWallet!.id,
        );
        emit(
          state.copyWith(
            unsignedPsbt: pset,
            liquidAbsoluteFees: absoluteFees,
            buildingTransaction: false,
          ),
        );
      } else {
        final psbtAndTxSize = await _prepareBitcoinSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: address,
          networkFee: state.selectedFee!,
          amountSat: amount,
          replaceByFee: state.replaceByFee,
          selectedInputs: state.selectedUtxos,
          // ignore: avoid_bool_literals_in_conditional_expressions
          drain: state.lightningSwap != null ? false : state.sendMax,
        );
        emit(
          state.copyWith(
            unsignedPsbt: psbtAndTxSize.unsignedPsbt,
            bitcoinTxSize: psbtAndTxSize.txSize,
            buildingTransaction: false,
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
      if (e is PrepareBitcoinSendException) {
        emit(
          state.copyWith(
            buildTransactionException: BuildTransactionException(e.message),
            buildingTransaction: false,
          ),
        );
        return;
      }
      if (e is PrepareLiquidSendException) {
        emit(
          state.copyWith(
            buildTransactionException: BuildTransactionException(e.message),
            buildingTransaction: false,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          buildTransactionException: BuildTransactionException(e.toString()),
          buildingTransaction: false,
        ),
      );
      return;
    }
  }

  Future<void> signTransaction() async {
    try {
      emit(state.copyWith(signingTransaction: true));

      if (state.selectedWallet!.network.isLiquid) {
        final signedPset = await _signLiquidTxUsecase.execute(
          psbt: state.unsignedPsbt!,
          walletId: state.selectedWallet!.id,
        );

        emit(
          state.copyWith(signedLiquidTx: signedPset, signingTransaction: false),
        );
      } else {
        final paymentRequest = state.paymentRequest;
        if (paymentRequest != null &&
            paymentRequest is Bip21PaymentRequest &&
            paymentRequest.pj.isNotEmpty) {
          final payjoinSender = await _sendWithPayjoinUsecase.execute(
            walletId: state.selectedWallet!.id,
            isTestnet: state.selectedWallet!.network.isTestnet,
            bip21: paymentRequest.uri,
            unsignedOriginalPsbt: state.unsignedPsbt!,
            amountSat: state.confirmedAmountSat!,
            networkFeesSatPerVb:
                state.selectedFee!.isRelative
                    ? state.selectedFee!.value as double
                    : 1,
            expireAfterSec: PayjoinConstants.defaultExpireAfterSec,
          );
          // TODO: Watch the payjoin and transaction to update the txId with the
          //  payjoin txId if it is completed.
          final txId = payjoinSender.originalTxId;
          emit(
            state.copyWith(
              txId: txId,
              payjoinSender: payjoinSender,
              signingTransaction: false,
            ),
          );
        } else {
          final signedPsbt = await _signBitcoinTxUsecase.execute(
            psbt: state.unsignedPsbt!,
            walletId: state.selectedWallet!.id,
          );

          emit(
            state.copyWith(
              signedBitcoinPsbt: signedPsbt,
              signingTransaction: false,
            ),
          );
        }
      }
    } catch (e) {
      emit(
        state.copyWith(
          confirmTransactionException: ConfirmTransactionException(
            e.toString(),
          ),
          signingTransaction: false,
        ),
      );
    }
  }

  Future<void> broadcastTransaction() async {
    try {
      emit(state.copyWith(broadcastingTransaction: true));

      if (state.selectedWallet!.network.isLiquid) {
        final txId = await _broadcastLiquidTxUsecase.execute(
          state.signedLiquidTx!,
        );
        emit(state.copyWith(txId: txId));
      } else {
        final paymentRequest = state.paymentRequest;
        if (paymentRequest != null &&
            paymentRequest is Bip21PaymentRequest &&
            paymentRequest.pj.isNotEmpty) {
          emit(state.copyWith(broadcastingTransaction: false));
        } else {
          final txId = await _broadcastBitcoinTxUsecase.execute(
            state.signedBitcoinPsbt!,
          );
          emit(state.copyWith(txId: txId));
        }
      }

      if (state.lightningSwap != null) {
        await _updatePaidSendSwapUsecase.execute(
          txid: state.txId!,
          swapId: state.lightningSwap!.id,
          network: state.selectedWallet!.network,
          absoluteFees: state.absoluteFees!,
        );
      }
      if (state.chainSwap != null) {
        await _updatePaidSendSwapUsecase.execute(
          txid: state.txId!,
          swapId: state.chainSwap!.id,
          network: state.selectedWallet!.network,
          absoluteFees: state.absoluteFees!,
        );
      }
      // await Future.delayed(const Duration(seconds: 3));
      // Start syncing the wallet now that the transaction is confirmed
      await _getWalletUsecase.execute(state.selectedWallet!.id, sync: true);

      emit(
        state.copyWith(broadcastingTransaction: false, step: SendStep.success),
      );
    } catch (e) {
      emit(
        state.copyWith(
          confirmTransactionException: ConfirmTransactionException(
            e.toString(),
          ),
          broadcastingTransaction: false,
        ),
      );
    }
  }

  Future<void> onConfirmTransactionClicked() async {
    try {
      await createTransaction();
      await signTransaction();
      // if (!state.isLightning) {
      emit(state.copyWith(step: SendStep.sending));
      // }
      await broadcastTransaction();
      emit(state.copyWith(step: SendStep.success));
      // Start watching the transaction to have the latest status
      _watchWalletTransactionByTxId(
        walletId: state.selectedWallet!.id,
        txId: state.txId!,
      );
      // Sync the wallet so the transaction is picked up by the watcher
      await _getWalletUsecase.execute(state.selectedWallet!.id, sync: true);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> currencyCodeChanged(String currencyCode) async {
    if (currencyCode == BitcoinUnit.btc.code ||
        currencyCode == BitcoinUnit.sats.code) {
      emit(
        state.copyWith(
          bitcoinUnit: BitcoinUnit.fromCode(currencyCode),
          inputAmountCurrencyCode: currencyCode,
          fiatCurrencyCode: 'CAD',
          amount: '0',
        ),
      );
      return;
    }
    await getExchangeRate(currencyCode: currencyCode);
    emit(
      state.copyWith(
        fiatCurrencyCode: currencyCode,
        inputAmountCurrencyCode: currencyCode,
        amount: '0',
      ),
    );
    // await updateFiatApproximatedAmount();
  }

  Future<void> getExchangeRate({String? currencyCode}) async {
    final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
      currencyCode: currencyCode ?? state.fiatCurrencyCode,
    );

    emit(state.copyWith(exchangeRate: exchangeRate));
  }

  // Future<void> updateFiatApproximatedAmount() async {
  //   double btcAmount;
  //   switch (state.bitcoinUnit) {
  //     case BitcoinUnit.btc:
  //       btcAmount = double.parse(state.amount);
  //     case BitcoinUnit.sats:
  //       btcAmount = approximateBtcFromSats(BigInt.parse(state.amount));
  //   }

  //   final approximatedValue = btcAmount * state.exchangeRate;
  //   emit(state.copyWith(fiatApproximatedAmount: approximatedValue.toString()));
  // }

  void onNumberPressed(String n) {
    amountChanged(state.amount + n);
    // updateFiatApproximatedAmount();
  }

  void onBackspacePressed() {
    if (state.amount.isEmpty) return;

    final newAmount = state.amount.substring(0, state.amount.length - 1);
    emit(state.copyWith(amount: newAmount));

    // updateFiatApproximatedAmount();
  }

  void _watchSendSwap(String swapId) {
    // Cancel the previous subscription if it exists
    _swapSubscription?.cancel();
    _swapSubscription = _watchSwapUsecase.execute(swapId).listen((updatedSwap) {
      debugPrint(
        '[SendCubit] Watched swap ${updatedSwap.id} updated: ${updatedSwap.status}',
      );
      if (updatedSwap is LnSendSwap) {
        emit(state.copyWith(lightningSwap: updatedSwap));
        if (updatedSwap.status == SwapStatus.completed) {
          // Start syncing the wallet now that the swap is completed
          _getWalletUsecase.execute(state.selectedWallet!.id, sync: true);
          emit(state.copyWith(step: SendStep.success));
        }
      }
      if (updatedSwap is ChainSwap) {
        emit(state.copyWith(chainSwap: updatedSwap));
        if (updatedSwap.status == SwapStatus.completed) {
          // Start syncing the wallet now that the swap is completed
          _getWalletUsecase.execute(state.selectedWallet!.id, sync: true);
          emit(state.copyWith(step: SendStep.success));
        }
      }
    });
  }

  void _watchWalletTransactionByTxId({
    required String walletId,
    required String txId,
  }) {
    // Cancel the previous subscription if it exists
    _txSubscription?.cancel();
    _txSubscription = _watchWalletTransactionByTxIdUsecase
        .execute(walletId: walletId, txId: txId)
        .listen((tx) {
          debugPrint(
            '[SendBloc] Watched transaction ${tx.txId} updated: ${tx.status}',
          );
          emit(state.copyWith(transaction: tx));
        });
  }
}
