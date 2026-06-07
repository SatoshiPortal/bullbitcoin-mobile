class BullnymException implements Exception {
  final String code;
  final String reason;
  final Map<String, dynamic>? details;
  final int? statusCode;

  const BullnymException({
    required this.code,
    required this.reason,
    this.details,
    this.statusCode,
  });

  @override
  String toString() => 'BullnymException($code): $reason';
}

class BullnymNetworkException extends BullnymException {
  BullnymNetworkException(String reason)
    : super(code: 'NetworkError', reason: reason);
}
