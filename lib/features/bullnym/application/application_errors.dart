enum BullnymErrorKind {
  network,
  timeout,
  serverRejectedRequest,
  unexpectedHttpStatus,
  emptyResponse,
  invalidServerResponse,
  signingFailed,
  unknown,
}

class BullnymException implements Exception {
  final BullnymErrorKind kind;
  final String code;
  final String diagnosticReason;
  final Map<String, dynamic>? diagnosticDetails;
  final int? statusCode;
  final bool retryable;

  const BullnymException({
    required this.kind,
    required this.code,
    required this.diagnosticReason,
    this.diagnosticDetails,
    this.statusCode,
    required this.retryable,
  });

  const BullnymException.invalidServerResponse({
    String diagnosticReason = 'Invalid Bullnym server response',
    int? statusCode,
  }) : this(
         kind: BullnymErrorKind.invalidServerResponse,
         code: 'InvalidServerResponse',
         diagnosticReason: diagnosticReason,
         statusCode: statusCode,
         retryable: true,
       );

  const BullnymException.signingFailed(Object error)
    : this(
        kind: BullnymErrorKind.signingFailed,
        code: 'SigningFailed',
        diagnosticReason: 'Bullnym request signing failed: $error',
        retryable: false,
      );

  @override
  String toString() => 'BullnymException($code): $diagnosticReason';
}
