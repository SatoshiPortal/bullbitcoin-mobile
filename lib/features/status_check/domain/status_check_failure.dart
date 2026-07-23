import 'package:bb_mobile/core/failures/failure.dart';

sealed class StatusCheckFailure extends Failure {
  const StatusCheckFailure([super.logMessage]);
}

final class NoDefaultWalletFailure extends StatusCheckFailure {
  const NoDefaultWalletFailure();
}

final class StatusCheckUnexpectedFailure extends StatusCheckFailure {
  const StatusCheckUnexpectedFailure([super.logMessage]);
}
