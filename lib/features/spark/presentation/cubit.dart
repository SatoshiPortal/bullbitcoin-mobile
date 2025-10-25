import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/spark/entities/spark_wallet.dart';
import 'package:bb_mobile/core/spark/errors.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/spark/presentation/state.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SparkCubit extends Cubit<SparkState> {
  final SparkWalletEntity wallet;
  final ConvertSatsToCurrencyAmountUsecase convertSatsToCurrencyAmountUsecase;
  final GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase;
  final WalletBloc walletBloc;

  StreamSubscription<SdkEvent>? _eventSubscription;

  SparkCubit({
    required this.wallet,
    required this.convertSatsToCurrencyAmountUsecase,
    required this.getAvailableCurrenciesUsecase,
    required this.walletBloc,
  }) : super(const SparkState()) {
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _eventSubscription = wallet.eventStream().listen(
      (event) {
        log.info('Spark SDK Event: $event');
        // Reload data when sync or payment events occur
        if (event is SdkEvent_Synced || event is SdkEvent_PaymentSucceeded) {
          unawaited(load());
        }
      },
      onError: (error) {
        log.warning('Spark SDK Event Error: $error');
      },
    );
  }

  Future<void> load() async {
    try {
      emit(state.copyWith(isLoading: true));
      final (
        balance,
        payments,
        receiveAddress,
        exchangeRate,
        fiatCurrencyCodes,
      ) = await (
            wallet.balance,
            wallet.paymentHistory,
            wallet.sparkAddress,
            convertSatsToCurrencyAmountUsecase.execute(
              currencyCode: state.currencyCode,
            ),
            getAvailableCurrenciesUsecase.execute(),
          ).wait;

      emit(
        state.copyWith(
          sparkBalance: balance,
          payments: payments,
          receiveAddress: receiveAddress,
          exchangeRate: exchangeRate,
          fiatCurrencyCodes: fiatCurrencyCodes,
        ),
      );

      // Update wallet bloc with balance
      walletBloc.add(RefreshSparkWalletBalance(amount: balance.balanceSats));
    } catch (e) {
      log.warning(e.toString());
      emit(state.copyWith(error: SparkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> onSendCurrencyCodeChanged(String code) async {
    try {
      emit(state.copyWith(isLoading: true));
      final exchangeRate = await convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: code,
      );
      emit(state.copyWith(currencyCode: code, exchangeRate: exchangeRate));
    } catch (e) {
      emit(state.copyWith(error: SparkError(e.toString())));
      log.warning(e.toString());
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> updateSendAddress(String value) async {
    final trimmedValue = value.trim();
    emit(state.copyWith(sendAddress: trimmedValue, prepareResponse: null));
  }

  Future<void> prepareSendPayment(int amountSats) async {
    try {
      emit(state.copyWith(isLoading: true));
      final prepareResponse = await wallet.prepareSendPayment(
        paymentRequest: state.sendAddress,
        amountSats: amountSats,
      );
      emit(state.copyWith(prepareResponse: prepareResponse));
    } catch (e) {
      emit(state.copyWith(error: SparkError(e.toString())));
      log.warning(e.toString());
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> sendPayment({SendPaymentOptions? options}) async {
    if (state.prepareResponse == null) {
      emit(state.copyWith(error: SparkError('Payment not prepared')));
      return;
    }

    try {
      emit(state.copyWith(isLoading: true));
      final response = await wallet.sendPayment(
        prepareResponse: state.prepareResponse!,
        options: options,
      );

      final paymentId = response.payment.id;
      emit(state.copyWith(txid: paymentId));

      // Reload to get updated balance and payment history
      unawaited(load());
    } catch (e) {
      emit(state.copyWith(error: SparkError(e.toString())));
      log.warning(e.toString());
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  void clearError() => emit(state.copyWith(error: null));

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    return super.close();
  }
}
