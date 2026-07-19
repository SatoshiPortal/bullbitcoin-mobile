import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';

class PrivateInvoiceLink {
  static final RegExp _key = RegExp(r'^[A-Za-z0-9_-]{43}$');

  final InvoiceId invoiceId;
  final String value;

  const PrivateInvoiceLink._({required this.invoiceId, required this.value});

  factory PrivateInvoiceLink.fromServer({
    required String invoiceUrl,
    required InvoiceId expectedInvoiceId,
    required String viewingKey,
    required Uri expectedOrigin,
  }) {
    final uri = Uri.tryParse(invoiceUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.scheme != expectedOrigin.scheme ||
        uri.host != expectedOrigin.host ||
        uri.port != expectedOrigin.port ||
        !_key.hasMatch(viewingKey)) {
      throw ArgumentError.value('<redacted>', 'invoiceUrl');
    }
    final segments = uri.pathSegments;
    final validUnlinked =
        segments.length == 2 &&
        segments[0] == 'invoice' &&
        segments[1] == expectedInvoiceId.value;
    final validLinked =
        segments.length == 3 &&
        segments[1] == 'i' &&
        segments[2] == expectedInvoiceId.value &&
        segments[0].isNotEmpty;
    if (!validUnlinked && !validLinked) {
      throw ArgumentError.value('<redacted>', 'invoiceUrl');
    }
    return PrivateInvoiceLink._(
      invoiceId: expectedInvoiceId,
      value: uri.replace(fragment: 'v1.$viewingKey').toString(),
    );
  }

  factory PrivateInvoiceLink.stored({
    required InvoiceId invoiceId,
    required String value,
    required Uri expectedOrigin,
  }) {
    final uri = Uri.tryParse(value);
    final segments = uri?.pathSegments ?? const <String>[];
    final validUnlinked =
        segments.length == 2 &&
        segments[0] == 'invoice' &&
        segments[1] == invoiceId.value;
    final validLinked =
        segments.length == 3 &&
        segments[0].isNotEmpty &&
        segments[1] == 'i' &&
        segments[2] == invoiceId.value;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.scheme != expectedOrigin.scheme ||
        uri.host != expectedOrigin.host ||
        uri.port != expectedOrigin.port ||
        uri.fragment.length != 46 ||
        !uri.fragment.startsWith('v1.') ||
        !_key.hasMatch(uri.fragment.substring(3)) ||
        (!validUnlinked && !validLinked)) {
      throw ArgumentError.value('<redacted>', 'value');
    }
    return PrivateInvoiceLink._(invoiceId: invoiceId, value: value);
  }

  @override
  String toString() => 'PrivateInvoiceLink(<redacted>)';
}
