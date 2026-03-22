part of 'dlc_instruments_cubit.dart';

@freezed
abstract class DlcInstrumentsState with _$DlcInstrumentsState {
  const factory DlcInstrumentsState({
    @Default(false) bool isLoading,
    @Default([]) List<DlcInstrument> instruments,
    DlcInstrument? selectedInstrument,
    Exception? error,
  }) = _DlcInstrumentsState;
  const DlcInstrumentsState._();
}
