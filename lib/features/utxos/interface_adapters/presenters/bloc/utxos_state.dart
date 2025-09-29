part of 'utxos_bloc.dart';

@freezed
sealed class UtxosState with _$UtxosState {
  const factory UtxosState({
    @Default([]) List<UtxoViewModel> utxos,
    @Default(false) bool isLoading,
    Exception? exception,
  }) = _UtxosState;
  const UtxosState._();

  UtxoViewModel? getUtxo(String txId, int index) {
    try {
      return utxos.firstWhere(
        (utxo) => utxo.txId == txId && utxo.index == index,
      );
    } catch (e) {
      return null;
    }
  }
}
