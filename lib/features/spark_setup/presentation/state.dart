import 'package:bb_mobile/core/spark/entities/spark_wallet.dart';
import 'package:bb_mobile/core/spark/errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class SparkSetupState with _$SparkSetupState {
  const factory SparkSetupState({
    SparkError? error,
    @Default(false) bool isLoading,
    SparkWalletEntity? wallet,
  }) = _SparkSetupState;
}
