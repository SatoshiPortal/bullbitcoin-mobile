import 'package:bb_mobile/core/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class ArkSetupState with _$ArkSetupState {
  const factory ArkSetupState({
    ArkError? error,
    @Default(false) bool isLoading,
    ArkWallet? wallet,
  }) = _ArkSetupState;
}
