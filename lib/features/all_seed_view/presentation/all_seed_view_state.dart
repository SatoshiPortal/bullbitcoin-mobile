part of 'all_seed_view_cubit.dart';

@freezed
abstract class AllSeedViewState with _$AllSeedViewState {
  const factory AllSeedViewState({
    @Default(<Secret>[]) List<Secret> existingWallets,
    @Default(<Secret>[]) List<Secret> oldWallets,
    @Default(true) bool loading,
    @Default(false) bool seedsVisible,
    // Step-up authentication gate: raw seed phrases never leave secure
    // storage before the user re-confirms the app PIN on this screen.
    @Default(false) bool isUnlocked,
    SwapMasterKeyInfo? swapMasterKey,
    AllSeedViewFailure? failure,
  }) = _AllSeedViewState;
  const AllSeedViewState._();

  List<Secret> get allSeeds => [...existingWallets, ...oldWallets];
}
