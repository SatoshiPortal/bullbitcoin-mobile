import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';

/// The list/create view of an invoice (distinct from [InvoiceStatusSnapshot],
/// the public status shape — §3.11). Timestamps are `DateTime` (unix converted
/// only at the datasource boundary). Derived behaviour lives here so the UI and
/// the cubits never re-derive payability/cancellability inconsistently.
class Invoice {
  final InvoiceId id;

  /// Linked invoices carry the merchant nym; unlinked invoices (v1) carry null.
  /// The public URL scheme is chosen from this field.
  final String? nymOwner;
  final InvoiceStatus status;
  final int amountSat;
  final int remainingAmountSat;
  final int? fiatAmountMinor;
  final String? fiatCurrency;
  final String? publicDescription;
  final String? recipientName;
  final String? invoiceNumber;
  final bool acceptBtc;
  final bool acceptLn;
  final bool acceptLiquid;
  final String? bitcoinAddress;
  final String? liquidAddress;
  final DateTime createdAt;
  final DateTime expiresAt;
  final PaymentMethod? paidVia;
  final DateTime? paidAt;
  final int? paidAmountSat;

  const Invoice({
    required this.id,
    this.nymOwner,
    required this.status,
    required this.amountSat,
    required this.remainingAmountSat,
    this.fiatAmountMinor,
    this.fiatCurrency,
    this.publicDescription,
    this.recipientName,
    this.invoiceNumber,
    required this.acceptBtc,
    required this.acceptLn,
    required this.acceptLiquid,
    this.bitcoinAddress,
    this.liquidAddress,
    required this.createdAt,
    required this.expiresAt,
    this.paidVia,
    this.paidAt,
    this.paidAmountSat,
  });

  bool get isExpired => status == InvoiceStatus.expired;

  /// Still collectible: unpaid or partially paid, and not past expiry.
  bool isPayable(DateTime now) {
    final open =
        status == InvoiceStatus.unpaid || status == InvoiceStatus.partiallyPaid;
    return open && expiresAt.isAfter(now);
  }

  /// The server allows cancel only while `unpaid`; the affordance is offered
  /// only when this is true (§3.13 / DG-I5).
  bool get isCancellable => status == InvoiceStatus.unpaid;

  /// Zero once expired; never negative.
  Duration timeUntilExpiry(DateTime now) {
    final remaining = expiresAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// The public payment URL: `/<nym>/i/<id>` when linked, `/invoice/<id>` when
  /// unlinked (v1). [domain] is the base URL with no trailing slash.
  String publicUrlFor({required String domain}) {
    final base = domain.endsWith('/')
        ? domain.substring(0, domain.length - 1)
        : domain;
    return nymOwner != null
        ? '$base/$nymOwner/i/${id.value}'
        : '$base/invoice/${id.value}';
  }
}
