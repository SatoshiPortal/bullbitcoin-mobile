import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_failure.dart';

GetPaidFailure mapBullnymFailureToGetPaid(BullnymFailure failure) {
  return switch (failure.kind) {
    BullnymFailureKind.invalidServerResponse => GetPaidFailure.invalidResponse(
      logMessage: failure.logMessage,
    ),
    BullnymFailureKind.invalidInput || BullnymFailureKind.signingFailed =>
      GetPaidFailure.localPreparation(logMessage: failure.logMessage),
    BullnymFailureKind.network ||
    BullnymFailureKind.timeout ||
    BullnymFailureKind.serverRejectedRequest ||
    BullnymFailureKind.unexpectedHttpStatus ||
    BullnymFailureKind.emptyResponse ||
    BullnymFailureKind.unexpected => GetPaidFailure.unavailable(
      logMessage: failure.logMessage,
    ),
  };
}
