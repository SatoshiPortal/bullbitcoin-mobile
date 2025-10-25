import 'package:bb_mobile/core/spark/entities/spark_balance.dart';
import 'package:bb_mobile/core/spark/errors.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class SparkState with _$SparkState {
  const factory SparkState({
    SparkError? error,
    @Default(false) bool isLoading,

    // Balance & Payments
    SparkBalance? sparkBalance,
    @Default([]) List<Payment> payments,

    // Send
    @Default(0) double exchangeRate,
    @Default('CAD') String currencyCode,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String sendAddress,
    @Default('') String txid,
    PrepareSendPaymentResponse? prepareResponse,

    // Receive
    @Default('') String receiveAddress,
  }) = _SparkState;
}

extension SparkStateX on SparkState {
  int get totalBalance => sparkBalance?.totalSats ?? 0;
}
