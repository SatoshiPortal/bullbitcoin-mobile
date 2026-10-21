/// Reject malformed wire values as decoding failures, without quoting payloads.
/// A runtime programming error elsewhere is deliberately not caught here.
T decodeExchangeJson<T>(Object? value) {
  if (value is T) return value;
  throw const FormatException('Invalid exchange response value');
}
