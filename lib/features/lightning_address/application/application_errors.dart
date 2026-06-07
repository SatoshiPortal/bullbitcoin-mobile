import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';

enum LightningAddressErrorKind {
  invalidRegistrationInput,
  network,
  timeout,
  serverRejectedRequest,
  invalidServerResponse,
  signingFailed,
  unexpected,
}

class LightningAddressException implements Exception {
  final LightningAddressErrorKind kind;
  final String code;
  final bool retryable;

  const LightningAddressException({
    required this.kind,
    required this.code,
    required this.retryable,
  });

  factory LightningAddressException.fromBullnym(BullnymException error) {
    return LightningAddressException(
      kind: switch (error.kind) {
        BullnymErrorKind.invalidInput =>
          LightningAddressErrorKind.invalidRegistrationInput,
        BullnymErrorKind.network => LightningAddressErrorKind.network,
        BullnymErrorKind.timeout => LightningAddressErrorKind.timeout,
        BullnymErrorKind.serverRejectedRequest =>
          LightningAddressErrorKind.serverRejectedRequest,
        BullnymErrorKind.unexpectedHttpStatus ||
        BullnymErrorKind.emptyResponse ||
        BullnymErrorKind.invalidServerResponse =>
          LightningAddressErrorKind.invalidServerResponse,
        BullnymErrorKind.signingFailed =>
          LightningAddressErrorKind.signingFailed,
      },
      code: error.code,
      retryable: error.retryable,
    );
  }

  factory LightningAddressException.unexpected(Object error) {
    return LightningAddressException(
      kind: LightningAddressErrorKind.unexpected,
      code: error.runtimeType.toString(),
      retryable: false,
    );
  }

  @override
  String toString() => 'LightningAddressException($code)';
}
