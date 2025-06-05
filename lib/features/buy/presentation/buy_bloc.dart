// ignore_for_file: unused_field

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_buy_order_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' hide Network;
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_use_case.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'buy_bloc.freezed.dart';
part 'buy_event.dart';
part 'buy_state.dart';

class BuyBloc extends Bloc<BuyEvent, BuyState> {
  BuyBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required GetReceiveAddressUsecase getReceiveAddressUsecase,
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required ConfirmBuyOrderUsecase confirmBuyOrderUsecase,
    required CreateBuyOrderUsecase createBuyOrderUsecase,
    required GetOrderUsecase getOrderUsecase,
    required RefreshBuyOrderUsecase refreshBuyOrderUsecase,
  }) : _getWalletsUsecase = getWalletsUsecase,
       _getReceiveAddressUsecase = getReceiveAddressUsecase,
       _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _confirmBuyOrderUsecase = confirmBuyOrderUsecase,
       _createBuyOrderUsecase = createBuyOrderUsecase,
       _getOrderUsecase = getOrderUsecase,
       _refreshBuyOrderUsecase = refreshBuyOrderUsecase,
       super(const BuyState()) {
    on<_BuyStarted>(_onStarted);
    on<_BuyAmountInputChanged>(_onAmountInputChanged);
    on<_BuyCurrencyInputChanged>(_onCurrencyInputChanged);
    on<_BuySelectedWalletChanged>(_onSelectedWalletChanged);
    on<_BuyBitcoinAddressInputChanged>(_onBitcoinAddressInputChanged);
    on<_BuyCreateOrder>(_onCreateOrder);
    on<_BuyRefreshOrder>(_onRefreshOrder);
    on<_BuyConfirmOrder>(_onConfirmOrder);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final ConfirmBuyOrderUsecase _confirmBuyOrderUsecase;
  final CreateBuyOrderUsecase _createBuyOrderUsecase;
  final GetOrderUsecase _getOrderUsecase;
  final RefreshBuyOrderUsecase _refreshBuyOrderUsecase;

  Future<void> _onStarted(_BuyStarted event, Emitter<BuyState> emit) async {
    try {
      final summary = await _getExchangeUserSummaryUsecase.execute();
      emit(
        state.copyWith(
          userSummary: summary,
          getUserSummaryException: null,
          currencyInput: summary.currency,
        ),
      );

      final wallets = await _getWalletsUsecase.execute();
      emit(
        state.copyWith(
          wallets: wallets,
          selectedWallet: wallets.isNotEmpty ? wallets.first : null,
        ),
      );
    } catch (e) {
      debugPrint('[BuyBloc] _onStarted error: $e');
      if (e is GetExchangeUserSummaryException) {
        emit(state.copyWith(getUserSummaryException: e));
      } else if (e is GetWalletsException) {
        emit(state.copyWith(getWalletsException: e));
      }
    } finally {
      emit(state.copyWith(isStarted: true));
    }
  }

  Future<void> _onAmountInputChanged(
    _BuyAmountInputChanged event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(state.copyWith(amountInput: event.amount));
    } catch (e) {
      debugPrint('[BuyBloc] _onAmountInputChanged error: $e');
    }
  }

  Future<void> _onCurrencyInputChanged(
    _BuyCurrencyInputChanged event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(state.copyWith(currencyInput: event.currencyCode));
    } catch (e) {
      debugPrint('[BuyBloc] _onCurrencyInputChanged error: $e');
    }
  }

  Future<void> _onSelectedWalletChanged(
    _BuySelectedWalletChanged event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(state.copyWith(selectedWallet: event.wallet));
    } catch (e) {
      debugPrint('[BuyBloc] _onSelectedWalletChanged error: $e');
      if (e is GetReceiveAddressException) {
        emit(state.copyWith(getReceiveAddressException: e));
      }
    }
  }

  Future<void> _onBitcoinAddressInputChanged(
    _BuyBitcoinAddressInputChanged event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(state.copyWith(bitcoinAddressInput: event.bitcoinAddress));
    } catch (e) {
      debugPrint('[BuyBloc] _onBitcoinAddressInputChanged error: $e');
    }
  }

  Future<void> _onCreateOrder(
    _BuyCreateOrder event,
    Emitter<BuyState> emit,
  ) async {
    try {
      // Clear any previous exceptions and reset the buy order so that we create
      //  a new one on every Continue button press as the data may have changed.
      emit(
        state.copyWith(
          isCreatingOrder: true,
          buyOrder: null,
          getReceiveAddressException: null,
          createBuyOrderException: null,
        ),
      );

      final wallet = state.selectedWallet;
      String toAddress;
      if (wallet != null) {
        // If a wallet is selected, fetch the receive address for it.
        final walletAddress = await _getReceiveAddressUsecase.execute(
          walletId: wallet.id,
        );
        toAddress = walletAddress.address;
      } else {
        // If no wallet is selected, use the bitcoin address input.
        toAddress = state.bitcoinAddressInput;
      }
      final order = await _createBuyOrderUsecase.execute(
        toAddress: toAddress,
        orderAmount: FiatAmount(state.amount!),
        currency: state.currency,
        network:
            state.selectedWallet?.network.isLiquid == true
                ? Network.liquid
                : Network.bitcoin,
        isOwner: true,
      );

      emit(state.copyWith(buyOrder: order));
    } catch (e) {
      if (e is GetReceiveAddressException) {
        emit(state.copyWith(getReceiveAddressException: e));
      } else if (e is CreateBuyOrderException) {
        emit(state.copyWith(createBuyOrderException: e));
      }
    } finally {
      emit(state.copyWith(isCreatingOrder: false));
    }
  }

  Future<void> _onRefreshOrder(
    _BuyRefreshOrder event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(
        state.copyWith(isRefreshingOrder: true, refreshBuyOrderException: null),
      );

      final order = await _refreshBuyOrderUsecase.execute(
        orderId: state.buyOrder!.orderId,
      );

      emit(state.copyWith(buyOrder: order));
    } catch (e) {
      debugPrint('[BuyBloc] _onRefreshOrder error: $e');
      if (e is RefreshBuyOrderException) {
        emit(state.copyWith(refreshBuyOrderException: e));
      }
    } finally {
      emit(state.copyWith(isRefreshingOrder: false));
    }
  }

  Future<void> _onConfirmOrder(
    _BuyConfirmOrder event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(
        state.copyWith(isConfirmingOrder: true, confirmBuyOrderException: null),
      );

      final order = await _confirmBuyOrderUsecase.execute(
        orderId: state.buyOrder!.orderId,
      );

      emit(state.copyWith(buyOrder: order));
    } catch (e) {
      debugPrint('[BuyBloc] _onConfirmOrder error: $e');
      if (e is ConfirmBuyOrderException) {
        emit(state.copyWith(confirmBuyOrderException: e));
      }
    } finally {
      emit(state.copyWith(isConfirmingOrder: false));
    }
  }
}
