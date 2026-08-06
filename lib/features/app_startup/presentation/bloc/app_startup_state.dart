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

  /// Pre-v5 (2023–2024 "BULL") install detected: no longer migrated. The UI
  /// gates behind a backup screen. Carries no seed material — the sealed
  /// screen reads it itself.
  const factory AppStartupState.legacyBackupRequired() =
      AppStartupLegacyBackupRequired;
  const factory AppStartupState.failure(
    Object? e, {
    @Default(false) bool hasBackup,
  }) = AppStartupFailure;
}
