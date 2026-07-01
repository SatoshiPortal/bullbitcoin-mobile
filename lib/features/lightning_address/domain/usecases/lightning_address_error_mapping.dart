import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';

LightningAddressException mapBullnymToLightningAddressException(
  BullnymException error,
) {
  return switch (error.kind) {
    BullnymErrorKind.invalidInput =>
      LightningAddressException.invalidRegistrationInput(
        code: error.code,
        retryable: error.retryable,
      ),
    BullnymErrorKind.network => LightningAddressNetworkException(
      code: error.code,
      retryable: error.retryable,
    ),
    BullnymErrorKind.timeout => LightningAddressTimeoutException(
      code: error.code,
      retryable: error.retryable,
    ),
    BullnymErrorKind.serverRejectedRequest =>
      LightningAddressServerRejectedRequestException(
        code: error.code,
        retryable: error.retryable,
      ),
    BullnymErrorKind.unexpectedHttpStatus ||
    BullnymErrorKind.emptyResponse ||
    BullnymErrorKind.invalidServerResponse =>
      LightningAddressInvalidServerResponseException(
        code: error.code,
        retryable: error.retryable,
      ),
    BullnymErrorKind.signingFailed => LightningAddressSigningFailedException(
      code: error.code,
      retryable: error.retryable,
    ),
  };
}
