import 'dart:convert';

import 'package:bb_mobile/features/transactions/application/ports/transaction_export_saver.dart';
import 'package:file_picker/file_picker.dart';

class CsvTransactionExportSaver implements TransactionExportSaver {
  @override
  Future<bool> save(String csv) async {
    final now = DateTime.now().toUtc();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}Z';
    final filename = 'bull_transactions_${timestamp}.csv';
    final result = await FilePicker.platform.saveFile(
      bytes: utf8.encode(csv),
      fileName: filename,
    );
    return result != null;
  }
}
