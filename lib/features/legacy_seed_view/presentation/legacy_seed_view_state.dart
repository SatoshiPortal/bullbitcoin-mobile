part of 'legacy_seed_view_cubit.dart';

@freezed
abstract class LegacySeedViewState with _$LegacySeedViewState {
  const factory LegacySeedViewState({
    @Default(<OldSeed>[]) List<OldSeed> seeds,
    @Default(false) bool loading,
    String? error,
  }) = _LegacySeedViewState;
  const LegacySeedViewState._();
}
