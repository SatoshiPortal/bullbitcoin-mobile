/// The response did not have the expected shape.
///
/// Internal: a reader throws it inside an API operation, and the transport
/// reports it to callers as a `BbxResponseFormatFailure`. [reason] names the
/// invalid field and never quotes the value.
final class BbxFormatException implements Exception {
  final String reason;

  const BbxFormatException(this.reason);

  @override
  String toString() => 'BbxFormatException($reason)';
}
