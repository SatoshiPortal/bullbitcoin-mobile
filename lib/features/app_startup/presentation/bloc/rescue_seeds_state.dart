import 'package:bb_mobile/core/seed/domain/entity/seed.dart';

class RescueSeedsState {
  final bool isLoading;
  final List<MnemonicSeed> seeds;
  final bool seedsVisible;
  final String? error;

  const RescueSeedsState({
    this.isLoading = true,
    this.seeds = const [],
    this.seedsVisible = false,
    this.error,
  });

  RescueSeedsState copyWith({
    bool? isLoading,
    List<MnemonicSeed>? seeds,
    bool? seedsVisible,
    String? error,
  }) {
    return RescueSeedsState(
      isLoading: isLoading ?? this.isLoading,
      seeds: seeds ?? this.seeds,
      seedsVisible: seedsVisible ?? this.seedsVisible,
      error: error,
    );
  }
}
