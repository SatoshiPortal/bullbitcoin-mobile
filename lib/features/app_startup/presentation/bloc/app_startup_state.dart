part of 'app_startup_bloc.dart';

@freezed
sealed class AppStartupState with _$AppStartupState {
  const factory AppStartupState.initial() = AppStartupInitial;
  const factory AppStartupState.loadingInProgress({
    @Default(false) bool requiresMigration,
    @Default(false) bool v4MigrationComplete,
    @Default(false) bool v5MigrationComplete,
  }) = AppStartupLoadingInProgress;
  const factory AppStartupState.success({
    @Default(false) bool isPinCodeSet,
    @Default(false) bool hasDefaultWallets,
  }) = AppStartupSuccess;
  const factory AppStartupState.failure(
    Object? e, {
    @Default(false) bool hasBackup,
  }) = AppStartupFailure;
}
