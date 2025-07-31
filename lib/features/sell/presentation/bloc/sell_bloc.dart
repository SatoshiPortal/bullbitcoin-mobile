import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' hide Network;
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sell_bloc.freezed.dart';
part 'sell_event.dart';
part 'sell_state.dart';

class SellBloc extends Bloc<SellEvent, SellState> {
  SellBloc({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required GetSettingsUsecase getSettingsUsecase,
    required CreateSellOrderUsecase createSellOrderUsecase,
    required RefreshSellOrderUsecase refreshSellOrderUsecase,
    required PrepareBitcoinSendUsecase prepareBitcoinSendUsecase,
    required PrepareLiquidSendUsecase prepareLiquidSendUsecase,
    required SignBitcoinTxUsecase signBitcoinTxUsecase,
    required SignLiquidTxUsecase signLiquidTxUsecase,
    required BroadcastBitcoinTransactionUsecase
    broadcastBitcoinTransactionUsecase,
    required BroadcastLiquidTransactionUsecase
    broadcastLiquidTransactionUsecase,
    required GetNetworkFeesUsecase getNetworkFeesUsecase,
    required CalculateLiquidAbsoluteFeesUsecase
    calculateLiquidAbsoluteFeesUsecase,
    required CalculateBitcoinAbsoluteFeesUsecase
    calculateBitcoinAbsoluteFeesUsecase,
    required ConvertSatsToCurrencyAmountUsecase
    convertSatsToCurrencyAmountUsecase,
    required GetAddressAtIndexUsecase getAddressAtIndexUsecase,
    required GetWalletUtxosUsecase getWalletUtxosUsecase,
    required GetOrderUsecase getOrderUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _getSettingsUsecase = getSettingsUsecase,
       _createSellOrderUsecase = createSellOrderUsecase,
       _refreshSellOrderUsecase = refreshSellOrderUsecase,
       _prepareBitcoinSendUsecase = prepareBitcoinSendUsecase,
       _prepareLiquidSendUsecase = prepareLiquidSendUsecase,
       _signBitcoinTxUsecase = signBitcoinTxUsecase,
       _signLiquidTxUsecase = signLiquidTxUsecase,
       _broadcastBitcoinTransactionUsecase = broadcastBitcoinTransactionUsecase,
       _broadcastLiquidTransactionUsecase = broadcastLiquidTransactionUsecase,
       _getNetworkFeesUsecase = getNetworkFeesUsecase,
       _calculateLiquidAbsoluteFeesUsecase = calculateLiquidAbsoluteFeesUsecase,
       _calculateBitcoinAbsoluteFeesUsecase =
           calculateBitcoinAbsoluteFeesUsecase,
       _convertSatsToCurrencyAmountUsecase = convertSatsToCurrencyAmountUsecase,
       _getAddressAtIndexUsecase = getAddressAtIndexUsecase,
       _getWalletUtxosUsecase = getWalletUtxosUsecase,
       _getOrderUsecase = getOrderUsecase,
       super(const SellState.initial()) {
    on<SellStarted>(_onStarted);
    on<SellAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<SellWalletSelected>(_onWalletSelected);
    on<SellExternalWalletNetworkSelected>(_onExternalWalletNetworkSelected);
    on<SellOrderRefreshTimePassed>(_onOrderRefreshTimePassed);
    on<SellSendPaymentConfirmed>(_onSendPaymentConfirmed);
    on<SellPollOrderStatus>(_onPollOrderStatus);
    on<SellReplaceByFeeChanged>(_onReplaceByFeeChanged);
    on<SellUtxoSelected>(_onUtxoSelected);
    on<SellLoadUtxos>(_onLoadUtxos);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final CreateSellOrderUsecase _createSellOrderUsecase;
  final RefreshSellOrderUsecase _refreshSellOrderUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTransactionUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetOrderUsecase _getOrderUsecase;
  Timer? _pollingTimer;

  Future<void> _onStarted(SellStarted event, Emitter<SellState> emit) async {
    try {
      final userSummary = await _getExchangeUserSummaryUsecase.execute();
      final settings = await _getSettingsUsecase.execute();

      emit(
        SellState.amountInput(
          userSummary: userSummary,
          bitcoinUnit: settings.bitcoinUnit,
        ),
      );
    } on ApiKeyException catch (e) {
      emit(SellState.initial(apiKeyException: e));
    } on GetExchangeUserSummaryException catch (e) {
      emit(SellState.initial(getUserSummaryException: e));
    }
  }

  Future<void> _onAmountInputContinuePressed(
    SellAmountInputContinuePressed event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a clean SellWalletSelectionState state here
    final amountInputState = state.toCleanAmountInputState;
    if (amountInputState == null) {
      log.severe('Expected to be on SellAmountInputState but on: $state');
      return;
    }
    emit(amountInputState);

    OrderAmount orderAmount;
    if (event.isFiatCurrencyInput) {
      orderAmount = FiatAmount(double.parse(event.amountInput));
    } else {
      final amountBtc =
          amountInputState.bitcoinUnit == BitcoinUnit.sats
              ? ConvertAmount.satsToBtc(int.parse(event.amountInput))
              : double.parse(event.amountInput);
      orderAmount = BitcoinAmount(amountBtc);
    }

    emit(
      amountInputState.toWalletSelectionState(
        orderAmount: orderAmount,
        fiatCurrency: event.fiatCurrency,
      ),
    );
  }

  Future<void> _onWalletSelected(
    SellWalletSelected event,
    Emitter<SellState> emit,
  ) async {
    final walletSelectionState = state.toCleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe('Expected to be on SellWalletSelectionState but on: $state');
      return;
    }

    int requiredAmountSat;
    final exchangeRateEstimate = await _convertSatsToCurrencyAmountUsecase
        .execute(currencyCode: walletSelectionState.fiatCurrency.code);

    if (walletSelectionState.orderAmount.isFiat) {
      requiredAmountSat = ConvertAmount.fiatToSats(
        walletSelectionState.orderAmount.amount,
        exchangeRateEstimate,
      );
    } else {
      requiredAmountSat =
          walletSelectionState.bitcoinUnit == BitcoinUnit.btc
              ? ConvertAmount.btcToSats(walletSelectionState.orderAmount.amount)
              : walletSelectionState.orderAmount.amount.toInt();
    }

    if (event.wallet.balanceSat.toInt() < requiredAmountSat) {
      emit(
        walletSelectionState.copyWith(
          error: SellError.insufficientBalance(
            requiredAmountSat: requiredAmountSat,
          ),
        ),
      );
      return;
    }
    int absoluteFees = 0;
    try {
      final dummyAddressForFeeCalculation = await _getAddressAtIndexUsecase
          .execute(walletId: event.wallet.id, index: 0);

      if (event.wallet.isLiquid) {
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: event.wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: requiredAmountSat,
          networkFee: const NetworkFee.relative(0.1),
        );
        absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
        );
      } else {
        final bitcoinFees = await _getNetworkFeesUsecase.execute(
          isLiquid: false,
        );
        final fastestFee = bitcoinFees.fastest;

        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: event.wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: requiredAmountSat,
          networkFee: fastestFee,
        );
        absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
          feeRate: fastestFee.value as double,
        );
      }
    } catch (e) {
      emit(
        walletSelectionState.copyWith(
          error: SellError.unexpected(
            message: 'Failed to prepare transaction: $e',
          ),
        ),
      );
      return;
    }

    emit(walletSelectionState.copyWith(isCreatingSellOrder: true));

    try {
      final createdSellOrder = await _createSellOrderUsecase.execute(
        orderAmount: walletSelectionState.orderAmount,
        currency: walletSelectionState.fiatCurrency,
        network:
            event.wallet.isLiquid
                ? OrderBitcoinNetwork.liquid
                : OrderBitcoinNetwork.bitcoin,
      );

      if (!event.wallet.isLiquid) {
        final utxos = await _getWalletUtxosUsecase.execute(
          walletId: event.wallet.id,
        );
        emit(
          walletSelectionState.toSendPaymentState(
            selectedWallet: event.wallet,
            createdSellOrder: createdSellOrder,
            absoluteFees: absoluteFees,
            utxos: utxos,
            exchangeRateEstimate: exchangeRateEstimate,
          ),
        );
      } else {
        emit(
          walletSelectionState.toSendPaymentState(
            selectedWallet: event.wallet,
            createdSellOrder: createdSellOrder,
            absoluteFees: absoluteFees,
            exchangeRateEstimate: exchangeRateEstimate,
          ),
        );
      }
      _startPolling();
    } on PrepareLiquidSendException catch (e) {
      emit(
        walletSelectionState.copyWith(
          error: SellError.unexpected(message: e.message),
        ),
      );
    } on PrepareBitcoinSendException catch (e) {
      emit(
        walletSelectionState.copyWith(
          error: SellError.unexpected(message: e.message),
        ),
      );
    } on SellError catch (e) {
      emit(walletSelectionState.copyWith(error: e));
    } catch (e) {
      log.severe('Unexpected error in SellBloc: $e');
    } finally {
      if (state is SellWalletSelectionState) {
        emit(
          (state as SellWalletSelectionState).copyWith(
            isCreatingSellOrder: false,
          ),
        );
      }
    }
  }

  Future<void> _onExternalWalletNetworkSelected(
    SellExternalWalletNetworkSelected event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a SellWalletSelection or SellPaymentState and return
    //  to a clean SellWalletSelectionState state
    final walletSelectionState = state.toCleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe('Expected to be on SellWalletSelectionState but on: $state');
      return;
    }
    emit(walletSelectionState.copyWith(isCreatingSellOrder: true));

    try {
      final createdSellOrder = await _createSellOrderUsecase.execute(
        orderAmount: walletSelectionState.orderAmount,
        currency: walletSelectionState.fiatCurrency,
        network: event.network,
      );

      log.info('createdSellOrder: $createdSellOrder');
      // Proceed to confirmation state
      emit(
        walletSelectionState.toReceivePaymentState(
          createdSellOrder: createdSellOrder,
        ),
      );
      _startPolling();
    } on SellError catch (e) {
      emit(walletSelectionState.copyWith(error: e));
    } catch (e) {
      // Log unexpected errors
      log.severe('Unexpected error in SellBloc: $e');
    } finally {
      if (state is SellWalletSelectionState) {
        emit(
          (state as SellWalletSelectionState).copyWith(
            isCreatingSellOrder: false,
          ),
        );
      }
    }
  }

  Future<void> _onOrderRefreshTimePassed(
    SellOrderRefreshTimePassed event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a SellPaymentState
    final paymentState = state.toCleanPaymentState;
    if (paymentState == null) {
      log.severe('Expected to be on SellPaymentState but on: $state');
      return;
    }

    try {
      final refreshedOrder = await _refreshSellOrderUsecase.execute(
        orderId: paymentState.sellOrder.orderId,
      );

      emit(paymentState.copyWith(sellOrder: refreshedOrder));
    } on SellError catch (e) {
      emit(paymentState.copyWith(error: e));
    } catch (e) {
      log.severe('Unexpected error in SellBloc: $e');
    }
  }

  Future<void> _onSendPaymentConfirmed(
    SellSendPaymentConfirmed event,
    Emitter<SellState> emit,
  ) async {
    // We should be on a SellPaymentState
    final sellPaymentState = state.toCleanPaymentState;
    if (sellPaymentState == null) {
      log.severe('Expected to be on SellPaymentState but on: $state');
      return;
    }

    emit(sellPaymentState.copyWith(isConfirmingPayment: true));
    try {
      final wallet = sellPaymentState.selectedWallet;
      if (wallet == null) {
        throw const SellError.unexpected(
          message: 'No wallet selected to send payment',
        );
      }
      final isLiquid = wallet.isLiquid;
      final payinAmountSat = ConvertAmount.btcToSats(
        sellPaymentState.sellOrder.payinAmount,
      );
      if (isLiquid) {
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: wallet.id,
          address: sellPaymentState.sellOrder.liquidAddress!,
          amountSat: payinAmountSat,
          networkFee: const NetworkFee.relative(0.1),
        );
        final signedPset = await _signLiquidTxUsecase.execute(
          pset: pset,
          walletId: wallet.id,
        );
        await _broadcastLiquidTransactionUsecase.execute(signedPset);
      } else {
        final absoluteFees = sellPaymentState.absoluteFees;
        if (absoluteFees == null) {
          throw const SellError.unexpected(
            message: 'Transaction fees not calculated. Please try again.',
          );
        }
        final bitcoinFees = await _getNetworkFeesUsecase.execute(
          isLiquid: false,
        );
        final fastestFee = bitcoinFees.fastest;

        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: sellPaymentState.sellOrder.bitcoinAddress!,
          amountSat: payinAmountSat,
          networkFee: NetworkFee.absolute(absoluteFees),
          selectedInputs:
              sellPaymentState.selectedUtxos.isNotEmpty
                  ? sellPaymentState.selectedUtxos
                  : null,
          replaceByFee: sellPaymentState.replaceByFee,
        );
        final absoluteFeesUpdated = await _calculateBitcoinAbsoluteFeesUsecase
            .execute(
              psbt: preparedSend.unsignedPsbt,
              feeRate: fastestFee.value as double,
            );
        emit(sellPaymentState.copyWith(absoluteFees: absoluteFeesUpdated));
        final signedTx = await _signBitcoinTxUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
          walletId: wallet.id,
        );
        await _broadcastBitcoinTransactionUsecase.execute(
          signedTx.signedPsbt,
          isPsbt: true,
        );
      }
      // 5s delay gives backend time to register the 0 conf
      await Future.delayed(const Duration(seconds: 5));
      final latestOrder = await _getOrderUsecase.execute(
        orderId: sellPaymentState.sellOrder.orderId,
      );

      if (latestOrder is! SellOrder) {
        throw const SellError.unexpected(
          message: 'Expected SellOrder but received a different order type',
        );
      }

      emit(
        sellPaymentState.toSuccessState(sellOrder: sellPaymentState.sellOrder),
      );
    } on PrepareLiquidSendException catch (e) {
      emit(
        sellPaymentState.copyWith(
          error: SellError.unexpected(message: e.message),
        ),
      );
    } on PrepareBitcoinSendException catch (e) {
      emit(
        sellPaymentState.copyWith(
          error: SellError.unexpected(message: e.toString()),
        ),
      );
    } on SignLiquidTxException catch (e) {
      emit(
        sellPaymentState.copyWith(
          error: SellError.unexpected(message: e.toString()),
        ),
      );
    } on SignBitcoinTxException catch (e) {
      // Handle SellError and emit error state
      emit(
        sellPaymentState.copyWith(
          error: SellError.unexpected(message: e.toString()),
        ),
      );
    } catch (e) {
      // Log unexpected errors
      log.severe('Unexpected error in SellBloc: $e');
    } finally {
      if (state is SellPaymentState) {
        emit((state as SellPaymentState).copyWith(isConfirmingPayment: false));
      }
    }
  }

  Future<void> _onPollOrderStatus(
    SellPollOrderStatus event,
    Emitter<SellState> emit,
  ) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;

    try {
      final latestOrder = await _getOrderUsecase.execute(
        orderId: sellPaymentState.sellOrder.orderId,
      );

      if (latestOrder is! SellOrder) {
        log.severe('Expected SellOrder but received a different order type');
        return;
      }

      final payinStatus = latestOrder.payinStatus;

      if (payinStatus == OrderPayinStatus.inProgress ||
          payinStatus == OrderPayinStatus.awaitingConfirmation ||
          payinStatus == OrderPayinStatus.completed) {
        _stopPolling();
        emit(
          sellPaymentState
              .copyWith(sellOrder: latestOrder, isPolling: false)
              .toSuccessState(sellOrder: latestOrder),
        );
      } else {
        emit(
          sellPaymentState.copyWith(sellOrder: latestOrder, isPolling: true),
        );
      }
    } catch (e) {
      log.severe('Error polling order status: $e');
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      add(const SellEvent.pollOrderStatus());
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _onReplaceByFeeChanged(
    SellReplaceByFeeChanged event,
    Emitter<SellState> emit,
  ) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;
    emit(sellPaymentState.copyWith(replaceByFee: event.replaceByFee));
    await _recalculateFees(emit);
  }

  Future<void> _onUtxoSelected(
    SellUtxoSelected event,
    Emitter<SellState> emit,
  ) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;
    final selectedUtxos = List.of(sellPaymentState.selectedUtxos);

    if (selectedUtxos.contains(event.utxo)) {
      selectedUtxos.remove(event.utxo);
    } else {
      selectedUtxos.add(event.utxo);
    }

    emit(sellPaymentState.copyWith(selectedUtxos: selectedUtxos));
    await _recalculateFees(emit);
  }

  Future<void> _onLoadUtxos(
    SellLoadUtxos event,
    Emitter<SellState> emit,
  ) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;
    final wallet = sellPaymentState.selectedWallet;
    if (wallet == null) return;

    try {
      final utxos = await _getWalletUtxosUsecase.execute(walletId: wallet.id);
      emit(sellPaymentState.copyWith(utxos: utxos));
    } catch (e) {
      emit(
        sellPaymentState.copyWith(
          error: SellError.unexpected(message: 'Failed to load UTXOs: $e'),
        ),
      );
    }
  }

  Future<void> _recalculateFees(Emitter<SellState> emit) async {
    if (state is! SellPaymentState) return;

    final sellPaymentState = state as SellPaymentState;
    final wallet = sellPaymentState.selectedWallet;
    if (wallet == null) return;

    try {
      final payinAmountSat = ConvertAmount.btcToSats(
        sellPaymentState.sellOrder.payinAmount,
      );

      if (wallet.isLiquid) {
        final dummyAddressForFeeCalculation = await _getAddressAtIndexUsecase
            .execute(walletId: wallet.id, index: 0);
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: payinAmountSat,
          networkFee: const NetworkFee.relative(0.1),
        );
        final absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
        );
        emit(sellPaymentState.copyWith(absoluteFees: absoluteFees));
      } else {
        final bitcoinFees = await _getNetworkFeesUsecase.execute(
          isLiquid: false,
        );
        final fastestFee = bitcoinFees.fastest;

        final dummyAddressForFeeCalculation = await _getAddressAtIndexUsecase
            .execute(walletId: wallet.id, index: 0);
        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: payinAmountSat,
          networkFee: fastestFee,
          selectedInputs:
              sellPaymentState.selectedUtxos.isNotEmpty
                  ? sellPaymentState.selectedUtxos
                  : null,
          replaceByFee: sellPaymentState.replaceByFee,
        );
        final absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
          feeRate: fastestFee.value as double,
        );
        emit(sellPaymentState.copyWith(absoluteFees: absoluteFees));
      }
    } catch (e) {
      emit(
        sellPaymentState.copyWith(
          error: SellError.unexpected(
            message: 'Failed to recalculate fees: $e',
          ),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
