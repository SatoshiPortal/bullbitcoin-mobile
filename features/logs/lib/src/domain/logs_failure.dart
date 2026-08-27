import 'package:primitives/primitives.dart';

sealed class LogsFailure extends Failure {
  const LogsFailure([super.logMessage]);
}

final class LogsStorageFailure extends LogsFailure {
  const LogsStorageFailure([super.logMessage]);
}
