import 'package:bb_mobile/features/invoices/domain/entities/invoice_fallback_supervision.dart';
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
  final String? presentationStatus;
  final int amountSat;
  final int remainingAmountSat;
  final int? fiatAmountMinor;
  final String? fiatCurrency;
  final String? memo;
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
  final List<InvoiceFallbackSupervision> fallbackSupervisions;

  const Invoice({
    required this.id,
    this.nymOwner,
    required this.status,
    this.presentationStatus,
    required this.amountSat,
    required this.remainingAmountSat,
    this.fiatAmountMinor,
    this.fiatCurrency,
    this.memo,
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
    this.fallbackSupervisions = const [],
  });

  InvoiceFallbackState? get fallbackState =>
      mostUrgentInvoiceFallbackState(fallbackSupervisions);

  Invoice withFallbackSupervisions(
    List<InvoiceFallbackSupervision> supervisions,
  ) {
    return Invoice(
      id: id,
      nymOwner: nymOwner,
      status: status,
      presentationStatus: presentationStatus,
      amountSat: amountSat,
      remainingAmountSat: remainingAmountSat,
      fiatAmountMinor: fiatAmountMinor,
      fiatCurrency: fiatCurrency,
      memo: memo,
      acceptBtc: acceptBtc,
      acceptLn: acceptLn,
      acceptLiquid: acceptLiquid,
      bitcoinAddress: bitcoinAddress,
      liquidAddress: liquidAddress,
      createdAt: createdAt,
      expiresAt: expiresAt,
      paidVia: paidVia,
      paidAt: paidAt,
      paidAmountSat: paidAmountSat,
      fallbackSupervisions: List.unmodifiable(supervisions),
    );
  }

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
}
