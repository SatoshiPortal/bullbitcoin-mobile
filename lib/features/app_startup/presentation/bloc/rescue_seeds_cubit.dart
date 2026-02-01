import 'package:bb_mobile/features/app_startup/domain/usecases/get_rescue_seeds_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/rescue_seeds_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RescueSeedsCubit extends Cubit<RescueSeedsState> {
  RescueSeedsCubit({required GetRescueSeedsUsecase getRescueSeedsUsecase})
    : _getRescueSeedsUsecase = getRescueSeedsUsecase,
      super(const RescueSeedsState());

  final GetRescueSeedsUsecase _getRescueSeedsUsecase;

  Future<void> loadSeeds() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final seeds = await _getRescueSeedsUsecase.execute();
      emit(state.copyWith(isLoading: false, seeds: seeds, error: null));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void showSeeds() {
    emit(state.copyWith(seedsVisible: true));
  }

  void hideSeeds() {
    emit(state.copyWith(seedsVisible: false));
  }
}
