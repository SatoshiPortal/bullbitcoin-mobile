import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/transactions/application/ports/transaction_export_formatter.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';

// this covers self-custodial wallet activity only, not exchange orders
class ExportTransactionsCsvUsecase {
  final GetTransactionsUsecase _getTransactionsUsecase;
  final TransactionExportFormatter _formatter;

  ExportTransactionsCsvUsecase({
    required this._getTransactionsUsecase,
    required this._formatter,
  });

  @useResult
  Future<Result<String, TransactionFailure>> execute({
    DateTime? start,
    DateTime? end,
  }) async {
    if (start != null && end != null && start.isAfter(end)) {
      return const Err(TransactionExportInvalidRangeFailure());
    }

    final List<Transaction> transactions;
    switch (await _getTransactionsUsecase.execute()) {
      case Ok(:final value):
        transactions = value;
      case Err(:final failure):
        return Err(failure);
    }

    // Preserve the input's UTC-ness when rounding up to the next day:
    // building a plain (local) DateTime from a UTC end's wall-clock fields
    // shifted the inclusive-day boundary by the machine's UTC offset, so
    // the same export included or excluded edge transactions depending on
    // the device's timezone.
    final exclusiveEnd = end == null
        ? null
        : end.isUtc
        ? DateTime.utc(end.year, end.month, end.day + 1)
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
      return const Err(TransactionExportEmptyFailure());
    }

    try {
      return Ok(_formatter.format(rows));
    } catch (e, st) {
      log.severe(
        message: 'Failed to format the CSV export',
        error: e,
        trace: st,
      );
      return Err(TransactionExportFailure('format failed: ${e.runtimeType}'));
    }
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
