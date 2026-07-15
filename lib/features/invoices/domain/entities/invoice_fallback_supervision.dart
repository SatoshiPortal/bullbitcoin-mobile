import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';

/// Merchant-facing interpretation of Bullnym's authenticated automatic
/// fallback lifecycle. This is deliberately read-only: no state carries an
/// action, destination choice, or retry counter.
enum InvoiceFallbackState {
  delayed,
  inProgress,
  confirming,
  settled,
  integrityHold,
}

class InvoiceFallbackSupervision {
  final InvoiceId invoiceId;
  final String nym;
  final InvoiceFallbackState state;
  final int payerAmountSat;
  final int invoiceSwapAmountSat;
  final String lockupAddress;
  final String? fallbackAddress;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InvoiceFallbackSupervision({
    required this.invoiceId,
    required this.nym,
    required this.state,
    required this.payerAmountSat,
    required this.invoiceSwapAmountSat,
    required this.lockupAddress,
    this.fallbackAddress,
    this.transactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Anything short of confirmed settlement stays visible as supervision.
  bool get requiresAttention => state != InvoiceFallbackState.settled;
}

class InvoiceFallbackOverview {
  final List<InvoiceFallbackSupervision> items;
  final bool hasMore;

  const InvoiceFallbackOverview({required this.items, required this.hasMore});

  int get attentionCount =>
      items.where((item) => item.requiresAttention).length;

  List<InvoiceFallbackSupervision> forInvoice(InvoiceId invoiceId) => items
      .where((item) => item.invoiceId == invoiceId)
      .toList(growable: false);
}

/// Conservative wire mapping. The deployed projection's `refunded` state only
/// proves that a transaction id was journaled, so it remains `confirming`.
/// New lifecycle values approved by the contract are understood explicitly;
/// every unknown value remains in progress and never enables an action.
InvoiceFallbackState invoiceFallbackStateFromWire(String value) {
  return switch (value) {
    'refund_due' || 'eligible' || 'delayed' => InvoiceFallbackState.delayed,
    'refunding' ||
    'retrying' ||
    'constructed' ||
    'broadcast_ambiguous' ||
    'in_progress' => InvoiceFallbackState.inProgress,
    'refunded' ||
    'broadcast' ||
    'mempool' ||
    'confirming' => InvoiceFallbackState.confirming,
    'confirmed' || 'finalized' || 'settled' => InvoiceFallbackState.settled,
    'integrity_hold' => InvoiceFallbackState.integrityHold,
    _ => InvoiceFallbackState.inProgress,
  };
}

InvoiceFallbackState? mostUrgentInvoiceFallbackState(
  Iterable<InvoiceFallbackSupervision> items,
) {
  InvoiceFallbackState? selected;
  var selectedPriority = -1;
  for (final item in items) {
    final priority = switch (item.state) {
      InvoiceFallbackState.settled => 0,
      InvoiceFallbackState.confirming => 1,
      InvoiceFallbackState.inProgress => 2,
      InvoiceFallbackState.delayed => 3,
      InvoiceFallbackState.integrityHold => 4,
    };
    if (priority > selectedPriority) {
      selected = item.state;
      selectedPriority = priority;
    }
  }
  return selected;
}
