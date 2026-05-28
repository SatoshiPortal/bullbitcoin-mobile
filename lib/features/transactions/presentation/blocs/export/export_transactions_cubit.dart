import 'dart:convert';

import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';
import 'package:bb_mobile/features/transactions/application/usecases/export_transactions_csv_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/export/export_transactions_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExportTransactionsCubit extends Cubit<ExportTransactionsState> {
  final ExportTransactionsCsvUsecase _exportTransactionsCsvUsecase;

  ExportTransactionsCubit({
    required ExportTransactionsCsvUsecase exportTransactionsCsvUsecase,
  }) : _exportTransactionsCsvUsecase = exportTransactionsCsvUsecase,
       super(const ExportTransactionsState.initial());

  Future<void> exportCsv({DateTime? start, DateTime? end}) async {
    try {
      emit(const ExportTransactionsState.loading());

      final csv = await _exportTransactionsCsvUsecase.execute(
        start: start,
        end: end,
      );

      final filename =
          'bull_transactions_${DateTime.now().toUtc().toIso8601WithoutMilliseconds()}Z.csv';
      final result = await FilePicker.platform.saveFile(
        bytes: utf8.encode(csv),
        fileName: filename,
      );
      if (result == null) {
        emit(const ExportTransactionsState.initial());
        return;
      }

      emit(const ExportTransactionsState.success());
    } on NoTransactionsToExportError {
      emit(const ExportTransactionsState.noTransactions());
    } catch (e) {
      emit(ExportTransactionsState.error(message: e.toString()));
    }
  }
}
