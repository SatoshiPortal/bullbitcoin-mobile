import 'dart:convert';

const int privateInvoicePresentationMaxJsonBytes = 4094;

class PrivateInvoiceContact {
  final String? name;
  final String? corporateName;
  final String? address;
  final String? email;
  final String? phone;

  const PrivateInvoiceContact._({
    this.name,
    this.corporateName,
    this.address,
    this.email,
    this.phone,
  });

  factory PrivateInvoiceContact({
    String? name,
    String? corporateName,
    String? address,
    String? email,
    String? phone,
  }) {
    return PrivateInvoiceContact._(
      name: _normalize(name, field: 'name', maxBytes: 120),
      corporateName: _normalize(
        corporateName,
        field: 'corporate_name',
        maxBytes: 160,
      ),
      address: _normalize(
        address,
        field: 'address',
        maxBytes: 500,
        allowNewlines: true,
      ),
      email: _normalize(email, field: 'email', maxBytes: 254),
      phone: _normalize(phone, field: 'phone', maxBytes: 64),
    );
  }

  bool get isEmpty =>
      name == null &&
      corporateName == null &&
      address == null &&
      email == null &&
      phone == null;

  int get populatedFieldCount =>
      [name, corporateName, address, email, phone].whereType<String>().length;
}

class PrivateInvoiceDetails {
  final String? description;
  final String? number;
  final String? purchaseOrderReference;
  final String? invoiceDate;
  final String? paymentDeadline;

  const PrivateInvoiceDetails._({
    this.description,
    this.number,
    this.purchaseOrderReference,
    this.invoiceDate,
    this.paymentDeadline,
  });

  factory PrivateInvoiceDetails({
    String? description,
    String? number,
    String? purchaseOrderReference,
    String? invoiceDate,
    String? paymentDeadline,
  }) {
    return PrivateInvoiceDetails._(
      description: _normalize(
        description,
        field: 'description',
        maxBytes: 1000,
        allowNewlines: true,
      ),
      number: _normalize(number, field: 'number', maxBytes: 128),
      purchaseOrderReference: _normalize(
        purchaseOrderReference,
        field: 'purchase_order_reference',
        maxBytes: 128,
      ),
      invoiceDate: _normalizeDate(invoiceDate, field: 'invoice_date'),
      paymentDeadline: _normalizeDate(
        paymentDeadline,
        field: 'payment_deadline',
      ),
    );
  }

  bool get isEmpty =>
      description == null &&
      number == null &&
      purchaseOrderReference == null &&
      invoiceDate == null &&
      paymentDeadline == null;

  int get populatedFieldCount => [
    description,
    number,
    purchaseOrderReference,
    invoiceDate,
    paymentDeadline,
  ].whereType<String>().length;
}

class PrivateInvoicePresentation {
  final PrivateInvoiceContact? payer;
  final PrivateInvoiceDetails? invoice;
  final PrivateInvoiceContact? payee;

  const PrivateInvoicePresentation._({this.payer, this.invoice, this.payee});

  factory PrivateInvoicePresentation({
    PrivateInvoiceContact? payer,
    PrivateInvoiceDetails? invoice,
    PrivateInvoiceContact? payee,
  }) {
    return PrivateInvoicePresentation._(
      payer: payer == null || payer.isEmpty ? null : payer,
      invoice: invoice == null || invoice.isEmpty ? null : invoice,
      payee: payee == null || payee.isEmpty ? null : payee,
    );
  }

  int get populatedFieldCount =>
      (payer?.populatedFieldCount ?? 0) +
      (invoice?.populatedFieldCount ?? 0) +
      (payee?.populatedFieldCount ?? 0);
}

class PrivateInvoicePresentationException implements Exception {
  final String field;
  final String code;

  const PrivateInvoicePresentationException({
    required this.field,
    required this.code,
  });

  @override
  String toString() => 'PrivateInvoicePresentationException($field, $code)';
}

String? _normalize(
  String? value, {
  required String field,
  required int maxBytes,
  bool allowNewlines = false,
}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  for (final rune in normalized.runes) {
    final isAllowedNewline = allowNewlines && (rune == 0x0a || rune == 0x0d);
    if ((rune < 0x20 || rune == 0x7f) && !isAllowedNewline) {
      throw PrivateInvoicePresentationException(
        field: field,
        code: 'control_character',
      );
    }
  }
  if (utf8.encode(normalized).length > maxBytes) {
    throw PrivateInvoicePresentationException(field: field, code: 'too_long');
  }
  return normalized;
}

String? _normalizeDate(String? value, {required String field}) {
  final normalized = _normalize(value, field: field, maxBytes: 10);
  if (normalized == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(normalized);
  if (match == null) {
    throw PrivateInvoicePresentationException(field: field, code: 'date');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final candidate = DateTime.utc(year, month, day);
  if (candidate.year != year ||
      candidate.month != month ||
      candidate.day != day) {
    throw PrivateInvoicePresentationException(field: field, code: 'date');
  }
  return normalized;
}
