import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'export_transactions_state.freezed.dart';

@freezed
sealed class ExportTransactionsState with _$ExportTransactionsState {
  const factory ExportTransactionsState.initial() = _Initial;
  const factory ExportTransactionsState.loading() = _Loading;
  const factory ExportTransactionsState.success() = _Success;

  /// One variant for every way the export can fail: the reason is the typed
  /// failure, so the UI renders `toTranslated` instead of switching on it.
  const factory ExportTransactionsState.failure(TransactionFailure failure) =
      _Failure;
}
