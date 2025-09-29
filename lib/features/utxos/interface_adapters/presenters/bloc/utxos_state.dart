import 'package:bb_mobile/features/utxos/interface_adapters/view_models/utxo_view_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'utxos_state.freezed.dart';

@freezed
sealed class UtxosState with _$UtxosState {
  const factory UtxosState({
    required List<UtxoViewModel> utxos,
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
