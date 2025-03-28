import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transactions_state.freezed.dart';

@freezed
class TransactionsState with _$TransactionsState {
  const factory TransactionsState({
    List<WalletTransaction>? transactions,
    @Default(false) bool loadingTxs,
    Object? err,
  }) = _TransactionsState;
  const TransactionsState._();
}
