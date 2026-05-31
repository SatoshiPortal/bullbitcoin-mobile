import 'package:freezed_annotation/freezed_annotation.dart';

part 'export_transactions_state.freezed.dart';

@freezed
sealed class ExportTransactionsState with _$ExportTransactionsState {
  const factory ExportTransactionsState.initial() = _Initial;
  const factory ExportTransactionsState.loading() = _Loading;
  const factory ExportTransactionsState.success() = _Success;
  const factory ExportTransactionsState.noTransactions() = _NoTransactions;
  const factory ExportTransactionsState.invalidDateRange() = _InvalidDateRange;
  const factory ExportTransactionsState.error() = _Error;
}
