import 'package:bb_mobile/_model/transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

enum TxLayout { onlyTx, onlySwapTx, both }

@freezed
class TransactionState with _$TransactionState {
  const factory TransactionState({
    required Transaction tx,
    @Default(false) bool loadingAddresses,
    @Default('') String errLoadingAddresses,
    @Default('') String label,
    @Default(false) bool savingLabel,
    @Default('') String errSavingLabel,
    //
    Transaction? updatedTx,
    // int? feeRate,
    @Default(false) bool buildingTx,
    @Default('') String errBuildingTx,
    @Default(false) bool sendingTx,
    @Default('') String errSendingTx,
    @Default(false) bool sentTx,
  }) = _TransactionState;
  const TransactionState._();

  bool showSaveButton() {
    if (label.isEmpty && label != tx.label) return false;
    return true;
  }
}

// extension X on Transaction {
//   TxLayout get pageLayout {
//     final swapTx = this.swapTx;
//     if (swapTx == null) return TxLayout.onlyTx;
//     final idMatches = swapTx.txid == txid;
//     if (idMatches) return TxLayout.both;
//     return TxLayout.onlySwapTx;
//   }
// }
