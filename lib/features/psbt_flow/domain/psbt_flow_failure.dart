import 'package:bb_mobile/core/failures/failure.dart';

sealed class PsbtFlowFailure extends Failure {
  const PsbtFlowFailure([super.logMessage]);
}

/// The PSBT could not be read at all — not valid base64, or rejected by the
/// PSBT parser. The user has to go back and rebuild the transaction.
final class PsbtFlowInvalidPsbtFailure extends PsbtFlowFailure {
  const PsbtFlowInvalidPsbtFailure();
}

/// The PSBT was readable but could not be encoded into QR parts: the encoder
/// threw, or returned nothing (a well-formed PSBT always yields at least one
/// part, so an empty result is a failure, not an empty state).
final class PsbtFlowQrEncodingFailure extends PsbtFlowFailure {
  const PsbtFlowQrEncodingFailure();
}

final class PsbtFlowUnexpectedFailure extends PsbtFlowFailure {
  const PsbtFlowUnexpectedFailure([super.logMessage]);
}
