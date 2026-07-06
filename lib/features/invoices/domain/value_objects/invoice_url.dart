/// A validated public invoice URL. HTTPS-only: a non-HTTPS (or unparseable)
/// URL is rejected so a hostile server `share_url` can never be rendered as a
/// navigable link (§8.8). The URL is only ever shown as text / opened via the
/// guarded external launcher — never webviewed.
class InvoiceUrl {
  final String value;

  const InvoiceUrl._(this.value);

  factory InvoiceUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw ArgumentError.value(value, 'InvoiceUrl', 'must be an HTTPS URL');
    }
    return InvoiceUrl._(trimmed);
  }

  @override
  bool operator ==(Object other) => other is InvoiceUrl && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
