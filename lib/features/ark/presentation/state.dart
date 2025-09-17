import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

enum ArkReceiveMethod { offchain, boarding }

@freezed
sealed class ArkState with _$ArkState {
  const factory ArkState({
    ArkError? error,
    @Default(false) bool isLoading,
    @Default(0) int pendingBalance,
    @Default(0) int confirmedBalance,
    @Default([]) List<ark_wallet.Transaction> transactions,
    @Default(ArkReceiveMethod.offchain) ArkReceiveMethod receiveMethod,
  }) = _ArkState;
}

extension ArkStateX on ArkState {
  bool get hasBoardingTransaction =>
      transactions.any((tx) => tx is ark_wallet.Transaction_Boarding);
}
