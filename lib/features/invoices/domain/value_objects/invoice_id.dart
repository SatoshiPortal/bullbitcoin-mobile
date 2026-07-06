/// A validated invoice id (the server's opaque identifier). Non-empty; the VO
/// keeps the raw server string as-is rather than re-parsing a UUID format, so a
/// future id scheme cannot reject a legitimate server id.
class InvoiceId {
  final String value;

  const InvoiceId._(this.value);

  factory InvoiceId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'InvoiceId', 'must not be empty');
    }
    return InvoiceId._(trimmed);
  }

  @override
  bool operator ==(Object other) => other is InvoiceId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
