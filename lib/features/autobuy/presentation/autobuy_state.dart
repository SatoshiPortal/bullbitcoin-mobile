part of 'autobuy_cubit.dart';

enum AutoBuyStep { intro, wallets, confirm }

@freezed
abstract class AutoBuyState with _$AutoBuyState {
  const factory AutoBuyState({
    @Default(AutoBuyStep.intro) AutoBuyStep step,
    @Default(false) bool isActive,
    @Default(true) bool isRestricted,
    @Default(false) bool isLoadingStatus,
    @Default(false) bool isSaving,
    @Default(false) bool statusChangeSucceeded,
    DefaultWallets? wallets,
    AutoBuyFailure? failure,
  }) = _AutoBuyState;
}
