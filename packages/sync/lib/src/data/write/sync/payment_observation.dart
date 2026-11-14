import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../../../domain/transaction_sync_failure.dart';

/// Missing observations must never be treated as an empty payment history.
Future<T?> collectPaymentObservation<T>(
  FutureOr<T> Function() collect, {
  void Function(String)? warning,
}) async {
  try {
    return await collect();
  } on Exception {
    (warning ?? log.warning)('Payment observation failed category=history');
    return null;
  }
}

/// Observation persistence cannot change an already committed sync outcome.
Future<Result<T, TransactionSyncFailure>> recordPaymentObservation<T>(
  Result<T, TransactionSyncFailure> result,
  Future<Result<void, TransactionSyncFailure>> Function(T) record,
) async {
  if (result case Ok(:final value)) {
    try {
      if (await record(value) case Err()) {
        log.warning('Payment observation failed category=outbox');
      }
    } on Exception {
      log.warning('Payment observation failed category=outbox');
    }
  }
  return result;
}
