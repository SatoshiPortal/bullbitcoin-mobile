import 'package:bb_mobile/core/failures/failure.dart';

sealed class TransactionFailure extends Failure {
  const TransactionFailure([super.logMessage]);
}

final class TransactionAggregationFailure extends TransactionFailure {
  const TransactionAggregationFailure([super.logMessage]);
}
