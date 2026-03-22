import 'package:bb_mobile/core/dlc/domain/entities/dlc_instrument.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_instruments_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_instruments_state.dart';
part 'dlc_instruments_cubit.freezed.dart';

class DlcInstrumentsCubit extends Cubit<DlcInstrumentsState> {
  DlcInstrumentsCubit({required GetInstrumentsUsecase getInstrumentsUsecase})
      : _getInstrumentsUsecase = getInstrumentsUsecase,
        super(const DlcInstrumentsState());

  final GetInstrumentsUsecase _getInstrumentsUsecase;

  Future<void> loadInstruments() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final instruments = await _getInstrumentsUsecase.execute();
      final selected = instruments.isNotEmpty ? instruments.first : null;
      emit(
        state.copyWith(
          isLoading: false,
          instruments: instruments,
          selectedInstrument: selected,
        ),
      );
    } on Exception catch (e) {
      emit(state.copyWith(isLoading: false, error: e));
    }
  }

  void selectInstrument(DlcInstrument instrument) {
    emit(state.copyWith(selectedInstrument: instrument));
  }

  Future<void> refresh() => loadInstruments();
}
