import 'dart:convert';

import 'package:transactions/src/domain/transaction_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:file_system/file_system.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SaveTransactionsCsvUsecase {
  final FileSystem _fileSystem;

  const SaveTransactionsCsvUsecase(this._fileSystem);

  @useResult
  Future<Result<bool, TransactionFailure>> execute(String csv) async {
    final now = DateTime.now().toUtc();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}Z';
    final filename = 'bull_transactions_$timestamp.csv';

    final result = await _fileSystem.save(
      bytes: utf8.encode(csv),
      filename: filename,
    );
    return result.mapErr((failure) {
      log.warning(
        'Failed to save the transactions CSV export',
        error: failure.logMessage,
      );
      return TransactionExportFailure('save failed: ${failure.logMessage}');
    });
  }
}
