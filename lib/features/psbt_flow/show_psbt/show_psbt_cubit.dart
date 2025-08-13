import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/show_psbt_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShowPsbtCubit extends Cubit<ShowPsbtState> {
  ShowPsbtCubit() : super(ShowPsbtState.initial());

  Future<void> generateBbqr(String psbt) async {
    try {
      emit(state.copyWith(isLoading: true, error: null));
      final parts = await Bbqr.splitPsbt(psbt);
      emit(state.copyWith(isLoading: false, bbqrParts: parts, error: null));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
