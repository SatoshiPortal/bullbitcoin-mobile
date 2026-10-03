import 'package:bb_mobile/core/failures/failure.dart';

sealed class LimitOrdersFailure extends Failure {
  const LimitOrdersFailure([super.logMessage]);
}

final class LimitOrdersAccountUnavailableFailure extends LimitOrdersFailure {
  const LimitOrdersAccountUnavailableFailure([super.logMessage]);
}

final class LimitOrdersMaximumActiveFailure extends LimitOrdersFailure {
  const LimitOrdersMaximumActiveFailure([super.logMessage]);
}

final class LimitOrderNotFoundFailure extends LimitOrdersFailure {
  const LimitOrderNotFoundFailure([super.logMessage]);
}

final class LimitOrderInvalidAddressFailure extends LimitOrdersFailure {
  const LimitOrderInvalidAddressFailure([super.logMessage]);
}

final class LimitOrderInvalidTargetFailure extends LimitOrdersFailure {
  const LimitOrderInvalidTargetFailure([super.logMessage]);
}

final class LimitOrderInvalidAmountFailure extends LimitOrdersFailure {
  const LimitOrderInvalidAmountFailure([super.logMessage]);
}

final class LimitOrdersLoadFailure extends LimitOrdersFailure {
  const LimitOrdersLoadFailure([super.logMessage]);
}

final class LimitOrderCreationFailure extends LimitOrdersFailure {
  const LimitOrderCreationFailure([super.logMessage]);
}

final class LimitOrderCancellationFailure extends LimitOrdersFailure {
  const LimitOrderCancellationFailure([super.logMessage]);
}

final class LimitOrdersUnexpectedFailure extends LimitOrdersFailure {
  const LimitOrdersUnexpectedFailure([super.logMessage]);
}
