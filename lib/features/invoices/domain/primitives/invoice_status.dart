/// The invoice lifecycle status. Wire values mirror the server enum EXACTLY
/// (`src/invoice.rs` list/status: `unpaid`, `in_progress`, `partially_paid`,
/// `paid`, `underpaid`, `overpaid`, `expired`, `cancelled`). [unsupported] is
/// the fail-closed compatibility state for newer server statuses.
enum InvoiceStatus {
  unpaid,
  inProgress,
  partiallyPaid,
  paid,
  underpaid,
  overpaid,
  expired,
  cancelled,
  unsupported;

  String get wire => switch (this) {
    InvoiceStatus.unpaid => 'unpaid',
    InvoiceStatus.inProgress => 'in_progress',
    InvoiceStatus.partiallyPaid => 'partially_paid',
    InvoiceStatus.paid => 'paid',
    InvoiceStatus.underpaid => 'underpaid',
    InvoiceStatus.overpaid => 'overpaid',
    InvoiceStatus.expired => 'expired',
    InvoiceStatus.cancelled => 'cancelled',
    InvoiceStatus.unsupported => 'unsupported',
  };

  /// Tolerant reader: unknown wire values fail closed as [unsupported]. The
  /// datasource logs the raw wire value for diagnostics before mapping.
  static InvoiceStatus fromWire(String wire) {
    return switch (wire) {
      'unpaid' => InvoiceStatus.unpaid,
      'in_progress' => InvoiceStatus.inProgress,
      'partially_paid' => InvoiceStatus.partiallyPaid,
      'paid' => InvoiceStatus.paid,
      'underpaid' => InvoiceStatus.underpaid,
      'overpaid' => InvoiceStatus.overpaid,
      'expired' => InvoiceStatus.expired,
      'cancelled' => InvoiceStatus.cancelled,
      _ => InvoiceStatus.unsupported,
    };
  }

  /// A terminal status: the status poll stops here (no further polling).
  bool get isTerminal => switch (this) {
    InvoiceStatus.paid ||
    InvoiceStatus.underpaid ||
    InvoiceStatus.overpaid ||
    InvoiceStatus.expired ||
    InvoiceStatus.cancelled => true,
    InvoiceStatus.unpaid ||
    InvoiceStatus.inProgress ||
    InvoiceStatus.partiallyPaid ||
    InvoiceStatus.unsupported => false,
  };

  bool get isUnsupported => this == InvoiceStatus.unsupported;
}
