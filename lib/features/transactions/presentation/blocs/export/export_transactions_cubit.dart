import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/application/ports/transaction_export_saver.dart';
import 'package:bb_mobile/features/transactions/application/usecases/export_transactions_csv_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/export/export_transactions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExportTransactionsCubit extends Cubit<ExportTransactionsState> {
  final ExportTransactionsCsvUsecase _exportTransactionsCsvUsecase;
  final TransactionExportSaver _saver;

  ExportTransactionsCubit({
    required this._exportTransactionsCsvUsecase,
    required this._saver,
  }) : super(const ExportTransactionsState.initial());

  Future<void> exportCsv({DateTime? start, DateTime? end}) async {
    emit(const ExportTransactionsState.loading());

    final String csv;
    switch (await _exportTransactionsCsvUsecase.execute(
      start: start,
      end: end,
    )) {
      case Ok(:final value):
        csv = value;
      case Err(:final failure):
        emit(ExportTransactionsState.failure(failure));
        return;
    }

    switch (await _saver.save(csv)) {
      // A cancelled save is not a failure: return to the idle form.
      case Ok(value: final saved):
        emit(
          saved
              ? const ExportTransactionsState.success()
              : const ExportTransactionsState.initial(),
        );
      case Err(:final failure):
        emit(ExportTransactionsState.failure(failure));
    }
  }
}
