import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'legacy_seed_view_cubit.freezed.dart';
part 'legacy_seed_view_state.dart';

class LegacySeedViewCubit extends Cubit<LegacySeedViewState> {
  LegacySeedViewCubit({required GetOldSeedsUsecase getOldSeedsUsecase})
    : _getOldSeedsUsecase = getOldSeedsUsecase,
      super(const LegacySeedViewState());

  final GetOldSeedsUsecase _getOldSeedsUsecase;

  Future<void> fetchOldSeeds() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final seeds = await _getOldSeedsUsecase.execute();
      emit(state.copyWith(loading: false, seeds: seeds, error: null));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void clearState() {
    emit(const LegacySeedViewState());
  }
}
