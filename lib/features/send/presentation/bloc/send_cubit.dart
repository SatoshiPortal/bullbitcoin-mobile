import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/send_errors.dart'
    show BroadcastTransactionException;
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
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
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
    required CalculateBitcoinAbsoluteFeesUsecase
    calculateBitcoinAbsoluteFeesUsecase,
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
       _calculateBitcoinAbsoluteFeesUsecase =
           calculateBitcoinAbsoluteFeesUsecase,
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

  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;

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
  Future<void> onScannedPaymentRequest(
    String scannedRawPaymentRequest,
    PaymentRequest? paymentRequest,
  ) async {
    clearAllExceptions();
    final sanitizedText = scannedRawPaymentRequest.trim().replaceAll(
      RegExp(r'^["\"]+|["\"]+$'),
      '',
    );
    emit(
      state.copyWith(
        scannedRawPaymentRequest: scannedRawPaymentRequest,
        copiedRawPaymentRequest: sanitizedText,
        paymentRequest: paymentRequest,
      ),
    );
    await continueOnAddressConfirmed();
  }

  /// Called when text is pasted or entered manually
  Future<void> onChangedText(String text) async {
    try {
      clearAllExceptions();
      final sanitizedText = text.trim().replaceAll(
        RegExp(r'^["\"]+|["\"]+$'),
        '',
      );
      final paymentRequest = await _detectBitcoinStringUsecase.execute(
        data: sanitizedText,
      );
      emit(
        state.copyWith(
          copiedRawPaymentRequest: sanitizedText,
          paymentRequest: paymentRequest,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          copiedRawPaymentRequest: text,
          paymentRequest: null,
          // Don't show exception if text field is clear
          invalidBitcoinStringException:
              text.isNotEmpty ? InvalidBitcoinStringException() : null,
        ),
      );
    }
  }

  Future<void> continueOnAddressConfirmed() async {
    try {
      emit(state.copyWith(loadingBestWallet: true, invoiceHasMrh: false));
      await unifiedBip21Prioritization();

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
              // copiedRawPaymentRequest: invoice.toString(),
              paymentRequest: updatedRequest,
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
      await loadFees();

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
        emit(
          state.copyWith(confirmedAmountSat: state.paymentRequest!.amountSat),
        );
        await handleChainSwap();
        if (state.swapAmountAboveLimit ||
            state.swapAmountBelowLimit ||
            state.swapCreationException != null) {
          return;
        }

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
        final swapType =
            wallet.isLiquid
                ? SwapType.liquidToLightning
                : SwapType.bitcoinToLightning;
        await loadSwapLimits();

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
          emit(
            state.copyWith(
              step: SendStep.confirm,
              lightningSwap: swap,
              confirmedAmountSat: state.paymentRequest!.amountSat,
              creatingSwap: false,
            ),
          );
          await createTransaction();
          // updateSwapLockupFees();
          return;
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
        if (state.paymentRequest!.amountSat == null) {
          emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
        } else {
          await handleChainSwap();
          if (state.swapAmountAboveLimit ||
              state.swapAmountBelowLimit ||
              state.swapCreationException != null) {
            return;
          }
          await createTransaction();
        }
        return;
      } else {
        emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
        return;
      }
    } catch (e) {
      if (e is NotEnoughFundsException) {
        emit(
          state.copyWith(
            loadingBestWallet: false,
            insufficientBalanceException: InsufficientBalanceException(),
            creatingSwap: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            invalidBitcoinStringException: InvalidBitcoinStringException(
              message: e.toString(),
            ),
            loadingBestWallet: false,
            creatingSwap: false,
          ),
        );
      }
    }
  }

  Future<void> handleChainSwap() async {
    final isChainSwap =
        (state.sendType == SendType.liquid &&
            !state.selectedWallet!.isLiquid) ||
        state.sendType == SendType.bitcoin && state.selectedWallet!.isLiquid ||
        state.isChainSwap;
    if (isChainSwap) {
      try {
        if (state.sendMax) {
          await buildDummyTxsForMaxSwapAmount();
        }
        final swapType =
            state.selectedWallet!.isLiquid
                ? SwapType.liquidToBitcoin
                : SwapType.bitcoinToLiquid;
        await loadSwapLimits();
        setSelectedSwapLimits();
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
        final amountSat =
            state.paymentRequest!.amountSat ?? state.inputAmountSat;
        final swap = await _createChainSwapToExternalUsecase.execute(
          sendWalletId: state.selectedWallet!.id,
          receiveAddress:
              state.paymentRequest!.isBip21
                  ? (state.paymentRequest! as Bip21PaymentRequest).address
                  : state.paymentRequestAddress,
          type: swapType,
          amountSat: amountSat,
        );
        _watchSendSwap(swap.id);
        emit(state.copyWith(creatingSwap: false));
        await Future.delayed(const Duration(seconds: 1));
        emit(
          state.copyWith(
            chainSwap: swap,
            confirmedAmountSat: swap.paymentAmount,
          ),
        );
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
    emit(
      state.copyWith(
        confirmedAmountSat: state.paymentRequest!.amountSat,
        step: SendStep.confirm,
        loadingBestWallet: false,
      ),
    );
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
          liquidLnSwapLimits: liquidSwapLimits,
          liquidLnSwapFees: liquidSwapFees,
          bitcoinLnSwapLimits: bitcoinSwapLimits,
          bitcoinLnSwapFees: bitcoinSwapFees,
        ),
      );
    }
    if (state.requireChainSwap) {
      final (
        (lbtcToBtcSwapLimits, lbtcToBtcSwapFees),
        (btcToLbtcSwapLimits, btcToLbtcSwapFees),
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
          btcToLbtcChainSwapLimits: btcToLbtcSwapLimits,
          btcToLbtcChainSwapFees: btcToLbtcSwapFees,
          lbtcToBtcChainSwapLimits: lbtcToBtcSwapLimits,
          lbtcToBtcChainSwapFees: lbtcToBtcSwapFees,
        ),
      );
    }
  }

  void setSelectedSwapLimits() {
    if (state.selectedWallet == null) return;

    final walletNetwork = state.selectedWallet!.network;
    switch (walletNetwork) {
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        if (state.paymentRequest?.isBolt11 == true ||
            state.paymentRequest?.isLnAddress == true) {
          emit(
            state.copyWith(
              selectedSwapFees: state.bitcoinLnSwapFees,
              selectedSwapLimits: state.bitcoinLnSwapLimits,
            ),
          );
        } else {
          emit(
            state.copyWith(
              selectedSwapFees: state.btcToLbtcChainSwapFees,
              selectedSwapLimits: state.btcToLbtcChainSwapLimits,
            ),
          );
        }
      case Network.liquidMainnet:
      case Network.liquidTestnet:
        if (state.paymentRequest?.isBolt11 == true ||
            state.paymentRequest?.isLnAddress == true) {
          emit(
            state.copyWith(
              selectedSwapFees: state.liquidLnSwapFees,
              selectedSwapLimits: state.liquidLnSwapLimits,
            ),
          );
        } else {
          emit(
            state.copyWith(
              selectedSwapFees: state.lbtcToBtcChainSwapFees,
              selectedSwapLimits: state.lbtcToBtcChainSwapLimits,
            ),
          );
        }
    }
  }

  Future<bool> hasBalance() async {
    if ((state.selectedWallet == null && state.paymentRequest == null) ||
        state.paymentRequest == null) {
      return false;
    }
    final wallet = state.selectedWallet!;
    final paymentRequest = state.paymentRequest!;
    switch (paymentRequest) {
      case Bolt11PaymentRequest _:
        // final swapLimits = state.swapLimits!.;
        final invoice = await _decodeInvoiceUsecase.execute(
          invoice: state.paymentRequestAddress,
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
        setSelectedSwapLimits();
        await _selectedWalletSyncingSubscription?.cancel();
        _selectedWalletSyncingSubscription = _watchFinishedWalletSyncsUsecase
            .execute(walletId: wallet.id)
            .listen((wallet) async {
              emit(state.copyWith(selectedWallet: wallet));
              await loadUtxos();
            });
      }
    } catch (e) {
      emit(state.copyWith(loadingBestWallet: false));
    }
  }

  void onMaxPressed() {
    if (state.selectedWallet == null) return;
    clearAllExceptions();
    emit(state.copyWith(amount: '0', sendMax: true));
  }

  void noteChanged(String note) => emit(state.copyWith(label: note));

  Future<void> onAmountConfirmed() async {
    clearAllExceptions();
    emit(
      state.copyWith(
        amountConfirmedClicked: true,
        confirmedAmountSat: state.inputAmountSat,
      ),
    );

    if (state.sendType == SendType.lightning) {
      if (state.selectedSwapLimits == null) {
        await loadSwapLimits();
        setSelectedSwapLimits();
      }
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
          lnAddress: state.paymentRequestAddress,
          amountSat: state.confirmedAmountSat,
        );
        emit(state.copyWith(creatingSwap: false));
        await Future.delayed(const Duration(seconds: 1));
        emit(
          state.copyWith(
            amountConfirmedClicked: false,
            step: SendStep.confirm,
            lightningSwap: swap,
          ),
        );
        _watchSendSwap(swap.id);
        await createTransaction();
        // updateSwapLockupFees();
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

    if (state.isChainSwap) {
      await handleChainSwap();
      if (state.swapAmountAboveLimit ||
          state.swapAmountBelowLimit ||
          state.swapCreationException != null) {
        return;
      }
      await createTransaction();
    }
    // updateSwapLockupFees();

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

  Future<void> utxoSelected(WalletUtxo utxo) async {
    final selectedUtxos = List.of(state.selectedUtxos);
    if (selectedUtxos.contains(utxo)) {
      selectedUtxos.remove(utxo);
    } else {
      selectedUtxos.add(utxo);
    }
    emit(state.copyWith(selectedUtxos: selectedUtxos));
    await createTransaction();
    // updateSwapLockupFees();
  }

  Future<void> replaceByFeeChanged(bool replaceByFee) async {
    emit(state.copyWith(replaceByFee: replaceByFee));
    await createTransaction();
  }

  Future<void> loadFees() async {
    if (state.selectedWallet == null) return;
    try {
      final bitcoinFees = await _getNetworkFeesUsecase.execute(isLiquid: false);
      final liquidFees = await _getNetworkFeesUsecase.execute(isLiquid: true);
      emit(
        state.copyWith(
          bitcoinFeesList: bitcoinFees,
          liquidFeesList: liquidFees,
          selectedFeeOption: FeeSelection.fastest,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> feeOptionSelected(FeeSelection feeSelection) async {
    emit(state.copyWith(selectedFeeOption: feeSelection));
    await createTransaction();
    // updateSwapLockupFees();
  }

  Future<void> customFeesChanged(NetworkFee fee) async {
    emit(
      state.copyWith(customFee: fee, selectedFeeOption: FeeSelection.custom),
    );

    await createTransaction();
    // updateSwapLockupFees();
  }

  Future<void> createTransaction() async {
    try {
      if (state.bitcoinFeesList == null || state.liquidFeesList == null) {
        throw 'Fees not loaded';
      }
      clearAllExceptions();
      await loadUtxos();
      emit(state.copyWith(buildingTransaction: true));
      final address =
          state.lightningSwap != null
              ? state.lightningSwap!.paymentAddress
              : (state.chainSwap != null)
              ? state.chainSwap!.paymentAddress
              : state.paymentRequest != null &&
                  state.paymentRequest is Bip21PaymentRequest
              ? (state.paymentRequest! as Bip21PaymentRequest).address
              : state.paymentRequestAddress;
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
        // final signedPset = await _signLiquidTxUsecase.execute(
        //   walletId: state.selectedWallet!.id,
        //   pset: pset,
        // );
        final absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
        );
        emit(
          state.copyWith(
            unsignedPsbt: pset,
            liquidAbsoluteFees: absoluteFees,
            buildingTransaction: false,
          ),
        );
        if (state.sendMax) {
          final maxAmountSat =
              state.selectedWallet!.balanceSat.toInt() -
              (state.absoluteFees ?? 0);
          // convert to btc or fiat based on selected currency
          final maxAmount =
              state.bitcoinUnit == BitcoinUnit.btc
                  ? ConvertAmount.satsToBtc(maxAmountSat)
                  : state.isInputAmountFiat
                  ? ConvertAmount.satsToFiat(maxAmountSat, state.exchangeRate)
                  : maxAmountSat;
          emit(
            state.copyWith(
              amount: maxAmount.toString(),
              confirmedAmountSat: state.inputAmountSat,
            ),
          );
        }
      } else {
        final unsignedPsbtAndTxSize = await _prepareBitcoinSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: address,
          networkFee: state.selectedFee!,
          amountSat: amount,
          replaceByFee: state.replaceByFee,
          selectedInputs: state.selectedUtxos,
          // ignore: avoid_bool_literals_in_conditional_expressions
          drain: state.lightningSwap != null ? false : state.sendMax,
        );

        if (state.selectedWallet!.signsRemotely) {
          emit(
            state.copyWith(
              unsignedPsbt: unsignedPsbtAndTxSize.unsignedPsbt,
              buildingTransaction: false,
            ),
          );
        } else {
          final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
            psbt: unsignedPsbtAndTxSize.unsignedPsbt,
            walletId: state.selectedWallet!.id,
          );
          // sign transaction and use signed psbt to calculate absolute fees

          emit(
            state.copyWith(
              unsignedPsbt: unsignedPsbtAndTxSize.unsignedPsbt,
              signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
              bitcoinTxSize: signedPsbtAndTxSize.txSize,
              buildingTransaction: false,
            ),
          );
        }
        if (state.sendMax) {
          final maxAmountSat =
              state.selectedWallet!.balanceSat.toInt() -
              (state.absoluteFees ?? 0);
          final maxAmount =
              state.bitcoinUnit == BitcoinUnit.btc
                  ? ConvertAmount.satsToBtc(maxAmountSat)
                  : state.isInputAmountFiat
                  ? ConvertAmount.satsToFiat(maxAmountSat, state.exchangeRate)
                  : maxAmountSat;
          emit(
            state.copyWith(
              amount: maxAmount.toString(),
              confirmedAmountSat: state.inputAmountSat,
            ),
          );
        }
      }
    } catch (e) {
      log.severe(e.toString());
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
          pset: state.unsignedPsbt!,
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
          final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
            psbt: state.unsignedPsbt!,
            walletId: state.selectedWallet!.id,
          );
          emit(
            state.copyWith(
              signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
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
            isPsbt: true,
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
          absoluteFees:
              0, // TODO (ishi): removed until server fees are implemented
        );
      }
      // await Future.delayed(const Duration(seconds: 3));
      // Start syncing the wallet now that the transaction is confirmed
      await _getWalletUsecase.execute(state.selectedWallet!.id, sync: true);

      emit(
        state.copyWith(broadcastingTransaction: false, step: SendStep.success),
      );
    } on GetWalletException catch (e) {
      emit(
        state.copyWith(
          confirmTransactionException: ConfirmTransactionException(e.message),
          broadcastingTransaction: false,
        ),
      );
    } on BroadcastTransactionException catch (_) {
      emit(
        state.copyWith(
          confirmTransactionException: ConfirmTransactionException(
            'Failed to broadcast transaction. Check your network connection and try again.',
          ),
          broadcastingTransaction: false,
        ),
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
      if (state.confirmTransactionException == null) {
        emit(state.copyWith(step: SendStep.sending));
      } else {
        emit(state.copyWith(step: SendStep.confirm));
        return;
      }
      // }
      await broadcastTransaction();
      if (state.confirmTransactionException != null) {
        emit(state.copyWith(step: SendStep.confirm));
        return;
      }
      // Start watching the transaction to have the latest status
      _watchWalletTransactionByTxId(
        walletId: state.selectedWallet!.id,
        txId: state.txId!,
      );
    } catch (e) {
      emit(state.copyWith(step: SendStep.confirm));
      log.severe(e.toString());
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
      log.info(
        '[SendCubit] Watched swap ${updatedSwap.id} updated: ${updatedSwap.status}',
      );
      if (updatedSwap is LnSendSwap) {
        emit(state.copyWith(lightningSwap: updatedSwap));
        if (updatedSwap.status == SwapStatus.completed ||
            updatedSwap.status == SwapStatus.canCoop) {
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
          log.info(
            '[SendBloc] Watched transaction ${tx.txId} updated: ${tx.status}',
          );
          emit(state.copyWith(walletTransaction: tx));
        });
  }

  Future<void> unifiedBip21Prioritization() async {
    final request = state.paymentRequest;
    if (request == null) return;
    if (request is! Bip21PaymentRequest) return;
    if (request.lightning.isEmpty) return;

    try {
      final lightning = await PaymentRequest.parse(request.lightning);
      final wallet = _bestWalletUsecase.execute(
        wallets: state.wallets,
        request: lightning,
        amountSat: lightning.amountSat,
      );
      emit(state.copyWith(selectedWallet: wallet, paymentRequest: lightning));
    } catch (_) {
      final wallet = _bestWalletUsecase.execute(
        wallets: state.wallets,
        request: request,
        amountSat: request.amountSat,
      );
      emit(state.copyWith(selectedWallet: wallet, paymentRequest: request));
    }
  }

  Future<void> buildDummyTxsForMaxSwapAmount() async {
    try {
      if (state.selectedWallet == null) return;
      clearAllExceptions();
      await loadSwapLimits();
      setSelectedSwapLimits();
      final swapLimits =
          state.selectedWallet!.isLiquid
              ? state.lbtcToBtcChainSwapLimits
              : state.btcToLbtcChainSwapLimits;
      if (swapLimits == null) return;
      if (state.selectedFee == null) await loadFees();
      final networkFee = state.selectedFee!;
      int absoluteFees;
      if (state.selectedWallet!.isLiquid) {
        const String dummySwapAddress =
            "lq1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0we046p4uqlt24";
        final dummyPset = await _prepareLiquidSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: dummySwapAddress,
          networkFee: networkFee,
          drain: true,
        );
        absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: dummyPset,
        );
        emit(state.copyWith(liquidAbsoluteFees: absoluteFees));
      } else {
        const String dummySwapAddress =
            "bc1p0e9sutev5p0whwkdqdzy6gw03m6g66zuullc4erh80u7qezneskq9pj5n4";
        final dummyDrainTxInfo = await _prepareBitcoinSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: dummySwapAddress,
          networkFee: networkFee,
          drain: true,
        );
        absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: dummyDrainTxInfo.unsignedPsbt,
          feeRate: networkFee.value as double,
        );
        emit(state.copyWith(bitcoinTxSize: dummyDrainTxInfo.txSize));
      }
      final balance = state.selectedWallet!.balanceSat.toInt();
      final maxAmount = balance - absoluteFees;
      if (state.bitcoinUnit == BitcoinUnit.sats) {
        emit(state.copyWith(amount: maxAmount.toString()));
      } else {
        final validatedAmount = ConvertAmount.satsToBtc(maxAmount);
        emit(state.copyWith(amount: validatedAmount.toString()));
      }
      if (swapLimits.min > maxAmount) {
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
    } catch (e) {
      emit(
        state.copyWith(
          buildTransactionException: BuildTransactionException(e.toString()),
        ),
      );
    }
  }
}
