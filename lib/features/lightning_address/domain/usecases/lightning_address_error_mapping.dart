import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';

LightningAddressException mapBullnymToLightningAddressException(
  BullnymFailure failure,
) {
  return switch (failure.kind) {
    BullnymFailureKind.invalidInput =>
      LightningAddressException.invalidRegistrationInput(
        code: failure.code,
        retryable: failure.retryable,
      ),
    BullnymFailureKind.network => LightningAddressNetworkException(
      code: failure.code,
      retryable: failure.retryable,
    ),
    BullnymFailureKind.timeout => LightningAddressTimeoutException(
      code: failure.code,
      retryable: failure.retryable,
    ),
    BullnymFailureKind.serverRejectedRequest =>
      LightningAddressServerRejectedRequestException(
        code: failure.code,
        retryable: failure.retryable,
      ),
    BullnymFailureKind.unexpectedHttpStatus ||
    BullnymFailureKind.emptyResponse ||
    BullnymFailureKind.invalidServerResponse =>
      LightningAddressInvalidServerResponseException(
        code: failure.code,
        retryable: failure.retryable,
      ),
    BullnymFailureKind.signingFailed => LightningAddressSigningFailedException(
      code: failure.code,
      retryable: failure.retryable,
    ),
    BullnymFailureKind.unexpected =>
      const LightningAddressException.unexpected(),
  };
}
