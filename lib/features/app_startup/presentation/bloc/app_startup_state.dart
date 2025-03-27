part of 'app_startup_bloc.dart';

@freezed
sealed class AppStartupState with _$AppStartupState {
  const factory AppStartupState.initial() = AppStartupInitial;
  const factory AppStartupState.loadingInProgress() =
      AppStartupLoadingInProgress;
  const factory AppStartupState.success({
    @Default(false) bool isPinCodeSet,
    @Default(false) bool hasDefaultWallets,
  }) = AppStartupSuccess;
  const factory AppStartupState.failure(Object? e) = AppStartupFailure;
}
