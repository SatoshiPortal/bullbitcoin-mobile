import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/legacy_seed_view/domain/get_legacy_seeds_usecase.dart';
import 'package:bb_mobile/features/legacy_seed_view/domain/legacy_seed_view_failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'legacy_seed_view_cubit.freezed.dart';
part 'legacy_seed_view_state.dart';

class LegacySeedViewCubit extends Cubit<LegacySeedViewState> {
  final GetLegacySeedsUsecase _getLegacySeedsUsecase;

  LegacySeedViewCubit({required this._getLegacySeedsUsecase})
    : super(const LegacySeedViewState());

  Future<void> fetchOldSeeds() async {
    emit(state.copyWith(loading: true, failure: null));
    switch (await _getLegacySeedsUsecase.execute()) {
      case Ok(:final value):
        emit(state.copyWith(loading: false, seeds: value, failure: null));
      case Err(:final failure):
        emit(state.copyWith(loading: false, failure: failure));
    }
  }

  void clearState() {
    emit(const LegacySeedViewState());
  }
}
