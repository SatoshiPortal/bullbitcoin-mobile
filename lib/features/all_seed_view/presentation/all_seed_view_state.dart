part of 'all_seed_view_cubit.dart';

@freezed
abstract class AllSeedViewState with _$AllSeedViewState {
  const factory AllSeedViewState({
    @Default(<MnemonicSeed>[]) List<MnemonicSeed> existingWallets,
    @Default(<MnemonicSeed>[]) List<MnemonicSeed> oldWallets,
    @Default(true) bool loading,
    @Default(false) bool seedsVisible,
    String? error,
  }) = _AllSeedViewState;
  const AllSeedViewState._();

  List<MnemonicSeed> get allSeeds => [...existingWallets, ...oldWallets];
}
