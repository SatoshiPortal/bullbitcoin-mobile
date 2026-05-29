import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/transactions/application/ports/transaction_export_saver.dart';
import 'package:bb_mobile/features/transactions/application/transactions_application_error.dart';
import 'package:bb_mobile/features/transactions/application/usecases/export_transactions_csv_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/export/export_transactions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExportTransactionsCubit extends Cubit<ExportTransactionsState> {
  final ExportTransactionsCsvUsecase _exportTransactionsCsvUsecase;
  final TransactionExportSaver _saver;

  ExportTransactionsCubit({
    required ExportTransactionsCsvUsecase exportTransactionsCsvUsecase,
    required TransactionExportSaver saver,
  }) : _exportTransactionsCsvUsecase = exportTransactionsCsvUsecase,
       _saver = saver,
       super(const ExportTransactionsState.initial());

  Future<void> exportCsv({DateTime? start, DateTime? end}) async {
    try {
      emit(const ExportTransactionsState.loading());

      final csv = await _exportTransactionsCsvUsecase.execute(
        start: start,
        end: end,
      );

      final saved = await _saver.save(csv);
      if (!saved) {
        emit(const ExportTransactionsState.initial());
        return;
      }

      emit(const ExportTransactionsState.success());
    } on NoTransactionsToExportError {
      emit(const ExportTransactionsState.noTransactions());
    } catch (e, s) {
      log.severe(
        message: 'Failed to export transactions CSV',
        error: e,
        trace: s,
      );
      emit(const ExportTransactionsState.error());
    }
  }
}
