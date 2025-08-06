import 'dart:math' as math;

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/errors/buy_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_new_receive_address_use_case.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'buy_bloc.freezed.dart';
part 'buy_event.dart';
part 'buy_state.dart';

class BuyBloc extends Bloc<BuyEvent, BuyState> {
  BuyBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required GetNewReceiveAddressUsecase getNewReceiveAddressUsecase,
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required ConfirmBuyOrderUsecase confirmBuyOrderUsecase,
    required CreateBuyOrderUsecase createBuyOrderUsecase,
    required RefreshBuyOrderUsecase refreshBuyOrderUsecase,
    required GetNetworkFeesUsecase getNetworkFeesUsecase,
    required ConvertSatsToCurrencyAmountUsecase
    convertSatsToCurrencyAmountUsecase,
    required AccelerateBuyOrderUsecase accelerateBuyOrderUsecase,
    required GetSettingsUsecase getSettingsUsecase,
  }) : _getWalletsUsecase = getWalletsUsecase,
       _getNewReceiveAddressUsecase = getNewReceiveAddressUsecase,
       _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _confirmBuyOrderUsecase = confirmBuyOrderUsecase,
       _createBuyOrderUsecase = createBuyOrderUsecase,
       _refreshBuyOrderUsecase = refreshBuyOrderUsecase,
       _getNetworkFeesUsecase = getNetworkFeesUsecase,
       _convertSatsToCurrencyAmountUsecase = convertSatsToCurrencyAmountUsecase,
       _accelerateBuyOrderUsecase = accelerateBuyOrderUsecase,
       _getSettingsUsecase = getSettingsUsecase,
       super(const BuyState()) {
    on<_BuyStarted>(_onStarted);
    on<_BuyAmountInputChanged>(_onAmountInputChanged);
    on<_BuyCurrencyInputChanged>(_onCurrencyInputChanged);
    on<_BuyFiatCurrencyInputToggled>(_onFiatCurrencyInputToggled);
    on<_BuySelectedWalletChanged>(_onSelectedWalletChanged);
    on<_BuyBitcoinAddressInputChanged>(_onBitcoinAddressInputChanged);
    on<_BuyCreateOrder>(_onCreateOrder);
    on<_BuyRefreshOrder>(_onRefreshOrder);
    on<_BuyConfirmOrder>(_onConfirmOrder);
    on<_BuyAccelerateTransactionPressed>(_onAccelerateTransactionPressed);
    on<_BuyAccelerateTransactionConfirmed>(_onAccelerateTransactionConfirmed);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final GetNewReceiveAddressUsecase _getNewReceiveAddressUsecase;
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final ConfirmBuyOrderUsecase _confirmBuyOrderUsecase;
  final CreateBuyOrderUsecase _createBuyOrderUsecase;
  final RefreshBuyOrderUsecase _refreshBuyOrderUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final AccelerateBuyOrderUsecase _accelerateBuyOrderUsecase;
  final GetSettingsUsecase _getSettingsUsecase;

  Future<void> _onStarted(_BuyStarted event, Emitter<BuyState> emit) async {
    try {
      final summary = await _getExchangeUserSummaryUsecase.execute();
      final settings = await _getSettingsUsecase.execute();
      final currencyInput = summary.currency ?? settings.currencyCode;
      emit(
        state.copyWith(
          userSummary: summary,
          apiKeyException: null,
          getUserSummaryException: null,
          currencyInput: currencyInput,
          bitcoinUnit: settings.bitcoinUnit,
        ),
      );

      final wallets = await _getWalletsUsecase.execute();
      // Always prefer the default liquid wallet if available, fallback to just
      // the first wallet if no default liquid wallet is found.
      final selectedWallet =
          wallets.isNotEmpty
              ? wallets.firstWhere(
                (w) => w.isDefault && w.isLiquid,
                orElse: () => wallets.first,
              )
              : null;

      emit(state.copyWith(wallets: wallets, selectedWallet: selectedWallet));

      try {
        final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: currencyInput,
        );
        emit(state.copyWith(exchangeRate: exchangeRate));
      } catch (e) {
        log.severe(
          '[BuyBloc] _onStarted convertSatsToCurrencyAmount error: $e',
        );
        if (e is ConvertSatsToCurrencyAmountException) {
          emit(state.copyWith(convertSatsToCurrencyAmountException: e));
        }
      }
    } catch (e) {
      log.severe('[BuyBloc] _onStarted error: $e');
      if (e is ApiKeyException) {
        // If the API key is invalid, we should not proceed with the buy flow.
        emit(state.copyWith(apiKeyException: e));
      }
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
      log.severe('[BuyBloc] _onAmountInputChanged error: $e');
    }
  }

  Future<void> _onCurrencyInputChanged(
    _BuyCurrencyInputChanged event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(state.copyWith(currencyInput: event.currencyCode));

      // Fetch the exchange rate for the new currency input.
      try {
        final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: event.currencyCode,
        );
        emit(state.copyWith(exchangeRate: exchangeRate));
      } catch (e) {
        log.severe(
          '[BuyBloc] _onStarted convertSatsToCurrencyAmount error: $e',
        );
        if (e is ConvertSatsToCurrencyAmountException) {
          emit(state.copyWith(convertSatsToCurrencyAmountException: e));
        }
      }
    } catch (e) {
      log.severe('[BuyBloc] _onCurrencyInputChanged error: $e');
    }
  }

  Future<void> _onFiatCurrencyInputToggled(
    _BuyFiatCurrencyInputToggled event,
    Emitter<BuyState> emit,
  ) async {
    try {
      // Toggle the fiat currency input state.
      emit(state.copyWith(isFiatCurrencyInput: !state.isFiatCurrencyInput));
    } catch (e) {
      log.severe('[BuyBloc] _onIsFiatCurrencyInputToggled error: $e');
    }
  }

  Future<void> _onSelectedWalletChanged(
    _BuySelectedWalletChanged event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(state.copyWith(selectedWallet: event.wallet));
    } catch (e) {
      log.severe('[BuyBloc] _onSelectedWalletChanged error: $e');
    }
  }

  Future<void> _onBitcoinAddressInputChanged(
    _BuyBitcoinAddressInputChanged event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(state.copyWith(bitcoinAddressInput: event.bitcoinAddress));
    } catch (e) {
      log.severe('[BuyBloc] _onBitcoinAddressInputChanged error: $e');
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
          getNewReceiveAddressException: null,
          createOrderBuyError: null,
        ),
      );

      final wallet = state.selectedWallet;
      String toAddress;
      if (wallet != null) {
        // If a wallet is selected, fetch the receive address for it.
        final walletAddress = await _getNewReceiveAddressUsecase.execute(
          walletId: wallet.id,
        );
        toAddress = walletAddress.address;
      } else {
        // If no wallet is selected, use the bitcoin address input.
        toAddress = state.bitcoinAddressInput;
      }
      final order = await _createBuyOrderUsecase.execute(
        toAddress: toAddress,
        orderAmount:
            state.isFiatCurrencyInput
                ? FiatAmount(state.amount!)
                : BitcoinAmount(state.amountBtc!),
        currency: state.currency!,
        isLiquid: state.selectedWallet?.network.isLiquid == true,
        isOwner: true,
      );

      emit(state.copyWith(buyOrder: order));
    } on BuyError catch (e) {
      log.severe('[BuyBloc] _onCreateOrder error: $e');
      emit(state.copyWith(createOrderBuyError: e));

      // Refresh the exchange rate so that the user can update the amount better
      //  if the amount was the reason for the error.
      try {
        final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: state.currency!.code,
        );
        emit(state.copyWith(exchangeRate: exchangeRate));
      } catch (e) {
        log.severe(
          '[BuyBloc] _onStarted convertSatsToCurrencyAmount error: $e',
        );
        if (e is ConvertSatsToCurrencyAmountException) {
          emit(state.copyWith(convertSatsToCurrencyAmountException: e));
        }
      }
    } on GetNewReceiveAddressException catch (e) {
      log.severe('[BuyBloc] _onCreateOrder GetNewReceiveAddressException: $e');
      emit(state.copyWith(getNewReceiveAddressException: e));
    } finally {
      emit(state.copyWith(isCreatingOrder: false));
    }
  }

  Future<void> _onRefreshOrder(
    _BuyRefreshOrder event,
    Emitter<BuyState> emit,
  ) async {
    try {
      final orderId = event.orderId ?? state.buyOrder!.orderId;

      emit(
        state.copyWith(isRefreshingOrder: true, refreshBuyOrderException: null),
      );

      final order = await _refreshBuyOrderUsecase.execute(orderId: orderId);

      emit(state.copyWith(buyOrder: order));
    } catch (e) {
      log.severe('[BuyBloc] _onRefreshOrder error: $e');
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
      log.severe('[BuyBloc] _onConfirmOrder error: $e');
      if (e is ConfirmBuyOrderException) {
        emit(state.copyWith(confirmBuyOrderException: e));
      }
    } finally {
      emit(state.copyWith(isConfirmingOrder: false));
    }
  }

  Future<void> _onAccelerateTransactionPressed(
    _BuyAccelerateTransactionPressed event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          refreshBuyOrderException: null,
          getNetworkFeesException: null,
          convertSatsToCurrencyAmountException: null,
        ),
      );

      final order = await _refreshBuyOrderUsecase.execute(
        orderId: event.orderId,
      );

      final (networkFees, exchangeRate) =
          await (
            _getNetworkFeesUsecase.execute(isLiquid: false),
            _convertSatsToCurrencyAmountUsecase.execute(
              currencyCode: order.payinCurrency,
            ),
          ).wait;

      emit(
        state.copyWith(
          buyOrder: order,
          accelerationNetworkFees: networkFees,
          exchangeRate: exchangeRate,
        ),
      );
    } catch (e) {
      log.severe('[BuyBloc] _onAccelerateTransactionPressed error: $e');

      if (e is RefreshBuyOrderException) {
        emit(state.copyWith(refreshBuyOrderException: e));
      } else if (e is GetNetworkFeesException) {
        emit(state.copyWith(getNetworkFeesException: e));
      } else if (e is ConvertSatsToCurrencyAmountException) {
        emit(state.copyWith(convertSatsToCurrencyAmountException: e));
      }
    }
  }

  Future<void> _onAccelerateTransactionConfirmed(
    _BuyAccelerateTransactionConfirmed event,
    Emitter<BuyState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          isAcceleratingOrder: true,
          accelerateBuyOrderException: null,
        ),
      );

      BuyOrder order = await _accelerateBuyOrderUsecase.execute(
        state.buyOrder!.orderId,
      );

      while (order.unbatchedBuyOnchainFees == null) {
        // Wait for the unbatched fees to be available
        await Future.delayed(const Duration(seconds: 3));
        order = await _refreshBuyOrderUsecase.execute(orderId: order.orderId);
      }

      emit(state.copyWith(buyOrder: order));
    } catch (e) {
      log.severe('[BuyBloc] _onAccelerateOrder error: $e');
      if (e is AccelerateBuyOrderException) {
        emit(state.copyWith(accelerateBuyOrderException: e));
      }
    } finally {
      emit(state.copyWith(isAcceleratingOrder: false));
    }
  }
}
