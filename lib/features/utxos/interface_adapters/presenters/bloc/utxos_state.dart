part of 'utxos_bloc.dart';

@freezed
sealed class UtxosState with _$UtxosState {
  const factory UtxosState({
    @Default([]) List<UtxoViewModel> utxos,
    @Default(false) bool isLoading,
    Exception? exception,
  }) = _UtxosState;
  const UtxosState._();

  UtxoViewModel? getUtxo(String outpoint) {
    try {
      return utxos.firstWhere((utxo) => utxo.outpoint == outpoint);
    } catch (e) {
      return null;
    }
  }
}
