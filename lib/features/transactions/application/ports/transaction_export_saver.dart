import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:meta/meta.dart';

abstract interface class TransactionExportSaver {
  /// Returns whether the user actually picked a destination — a cancelled
  /// save is not a failure. The adapter is the boundary: it catches whatever
  /// the platform throws and maps it to a [TransactionFailure].
  @useResult
  Future<Result<bool, TransactionFailure>> save(String csv);
}
