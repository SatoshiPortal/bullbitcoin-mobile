import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';

enum BullnymRequestPhase { authentication, read, write, delete }

sealed class BullnymFailure extends Failure {
  final BullnymRequestPhase phase;

  const BullnymFailure({required this.phase, String? logMessage})
    : super(logMessage);
}

final class BullnymInvalidInputFailure extends BullnymFailure {
  const BullnymInvalidInputFailure(String message)
    : super(phase: BullnymRequestPhase.write, logMessage: message);
}

final class BullnymAuthenticationFailure extends BullnymFailure {
  const BullnymAuthenticationFailure([String? message])
    : super(phase: BullnymRequestPhase.authentication, logMessage: message);
}

final class BullnymNetworkFailure extends BullnymFailure {
  final bool timeout;
  final bool outcomeUncertain;

  const BullnymNetworkFailure({
    required super.phase,
    required this.timeout,
    required this.outcomeUncertain,
    super.logMessage,
  });
}

final class BullnymServerFailure extends BullnymFailure {
  final String code;
  final int? statusCode;
  final bool retryable;
  final BullnymOwnedNameDetails? ownedNameDetails;

  const BullnymServerFailure({
    required super.phase,
    required this.code,
    required this.statusCode,
    required this.retryable,
    this.ownedNameDetails,
    super.logMessage,
  });
}

final class BullnymInvalidResponseFailure extends BullnymFailure {
  final int? statusCode;

  const BullnymInvalidResponseFailure({
    required super.phase,
    this.statusCode,
    super.logMessage,
  });
}

final class BullnymUnexpectedFailure extends BullnymFailure {
  const BullnymUnexpectedFailure({required super.phase, super.logMessage});
}
