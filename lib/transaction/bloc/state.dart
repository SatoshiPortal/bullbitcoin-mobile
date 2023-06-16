import 'package:bb_mobile/_model/transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class TransactionState with _$TransactionState {
  const factory TransactionState({
    required Transaction tx,
    @Default(false) bool loadingAddresses,
    @Default('') String errLoadingAddresses,
    @Default('') String label,
    @Default(false) bool savingLabel,
    @Default('') String errSavingLabel,
  }) = _TransactionState;
  const TransactionState._();

  bool showSaveButton() {
    if (label.isEmpty) return false;
    return label != tx.label;
  }
}
