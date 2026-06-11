import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/transactions/application/ports/transaction_export_formatter.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/application/application_errors.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';

// this covers self-custodial wallet activity only, not exchange orders
class ExportTransactionsCsvUsecase {
  final GetTransactionsUsecase _getTransactionsUsecase;
  final TransactionExportFormatter _formatter;

  ExportTransactionsCsvUsecase({
    required this._getTransactionsUsecase,
    required this._formatter,
  });

  Future<String> execute({DateTime? start, DateTime? end}) async {
    if (start != null && end != null && start.isAfter(end)) {
      throw InvalidDateRangeError();
    }

    final transactions = await _getTransactionsUsecase.execute();

    final exclusiveEnd = end == null
        ? null
        : DateTime(end.year, end.month, end.day + 1);

    final filtered = transactions.where((tx) {
      if (tx.isOrder) return false;
      if (tx.swap?.status == SwapStatus.expired) return false;
      final timestamp = tx.timestamp;
      if (timestamp == null) return start == null && exclusiveEnd == null;
      if (start != null && timestamp.isBefore(start)) return false;
      if (exclusiveEnd != null && !timestamp.isBefore(exclusiveEnd)) {
        return false;
      }
      return true;
    }).toList();

    final rows = filtered.toList()..sort(_byTimestamp);

    if (rows.isEmpty) {
      throw NoTransactionsToExportError();
    }

    return _formatter.format(rows);
  }

  int _byTimestamp(Transaction a, Transaction b) {
    final at = a.timestamp;
    final bt = b.timestamp;
    if (at == null && bt == null) return 0;
    if (at == null) return -1;
    if (bt == null) return 1;
    return bt.compareTo(at);
  }
}
