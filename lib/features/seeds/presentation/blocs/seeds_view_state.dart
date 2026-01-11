part of 'seeds_view_bloc.dart';

@freezed
abstract class SeedsViewState with _$SeedsViewState {
  const factory SeedsViewState.initial() = SeedsViewInitial;
  const factory SeedsViewState.loading() = SeedsViewLoading;
  const factory SeedsViewState.failedToLoad({
    required SeedsPresentationError error,
  }) = SeedsViewFailedToLoad;
  const factory SeedsViewState.loaded({
    @Default({}) Map<String, SeedSecret> seeds,
    @Default([]) List<String> inUseFingerprints,
    @Default(false) bool isSeedBeingDeleted,
    SeedsPresentationError? deletionError,
    @Default({}) Map<String, SeedSecret> legacySeeds,
  }) = SeedsViewLoaded;
  const SeedsViewState._();

  bool get isInitial => this is SeedsViewInitial;
  bool get isLoading => this is SeedsViewLoading;
  bool get hasLoadError => this is SeedsViewFailedToLoad;
  bool get isLoaded => this is SeedsViewLoaded;
  bool get isSeedBeingDeleted {
    return maybeWhen(
      loaded:
          (
            seeds,
            inUseFingerprints,
            isSeedBeingDeleted,
            deletionError,
            legacySeeds,
          ) => isSeedBeingDeleted,
      orElse: () => false,
    );
  }

  List<SeedViewModel> get allSeeds {
    return maybeWhen(
      loaded:
          (
            seeds,
            inUseFingerprints,
            isSeedBeingDeleted,
            deletionError,
            legacySeeds,
          ) {
            final seedModels = seeds.entries
                .map(
                  (e) => SeedViewModel(
                    fingerprint: e.key,
                    seedSecret: e.value,
                    isLegacy: false,
                    isInUse: inUseFingerprints.contains(e.key),
                  ),
                )
                .toList();
            final legacySeedModels = legacySeeds.entries
                .map(
                  (e) => SeedViewModel(
                    fingerprint: e.key,
                    seedSecret: e.value,
                    isLegacy: true,
                    isInUse: false,
                  ),
                )
                .toList();

            return [...seedModels, ...legacySeedModels];
          },
      orElse: () => [],
    );
  }
}
