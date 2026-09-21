import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/application/ports/transaction_export_saver.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:meta/meta.dart';

class CsvTransactionExportSaver implements TransactionExportSaver {
  @override
  @useResult
  Future<Result<bool, TransactionFailure>> save(String csv) async {
    final now = DateTime.now().toUtc();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}Z';
    final filename = 'bull_transactions_$timestamp.csv';

    try {
      final result = await FilePicker.platform.saveFile(
        bytes: utf8.encode(csv),
        fileName: filename,
      );
      return Ok(result != null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to save the transactions CSV export',
        error: e,
        trace: st,
      );
      return Err(TransactionExportFailure('save failed: ${e.runtimeType}'));
    }
  }
}
