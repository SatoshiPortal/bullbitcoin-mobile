import 'package:primitives/primitives.dart';

sealed class ArkFailure extends Failure {
  const ArkFailure();
}

final class ArkServiceUnavailableFailure extends ArkFailure {
  const ArkServiceUnavailableFailure();
}

final class ArkOperationBusyFailure extends ArkFailure {
  const ArkOperationBusyFailure();
}

final class ArkFeatureStorageFailure extends ArkFailure {
  const ArkFeatureStorageFailure();
}

final class ArkInvalidRequestFailure extends ArkFailure {
  const ArkInvalidRequestFailure();
}

final class ArkReviewExpiredFailure extends ArkFailure {
  const ArkReviewExpiredFailure();
}

final class ArkAccountRecoveryFailure extends ArkFailure {
  const ArkAccountRecoveryFailure();
}

final class ArkPaymentInsufficientFundsFailure extends ArkFailure {
  const ArkPaymentInsufficientFundsFailure();
}

final class ArkDisabledFailure extends ArkFailure {
  const ArkDisabledFailure();
}

final class ArkNetworkUnavailableFailure extends ArkFailure {
  const ArkNetworkUnavailableFailure();
}

final class ArkPrivacyDisclosureFailure extends ArkFailure {
  const ArkPrivacyDisclosureFailure();
}

final class ArkUnexpectedFailure extends ArkFailure {
  const ArkUnexpectedFailure();
}

final class ArkSubmissionUncertainFailure extends ArkFailure {
  final String operationId;
  const ArkSubmissionUncertainFailure(this.operationId);
}

final class ArkReminderUnavailableFailure extends ArkFailure {
  const ArkReminderUnavailableFailure();
}

final class ArkReminderMigrationFailure extends ArkFailure {
  const ArkReminderMigrationFailure();
}

final class ArkChildCollisionFailure extends ArkFailure {
  const ArkChildCollisionFailure();
}
