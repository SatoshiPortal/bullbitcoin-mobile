/// The invoice lifecycle status. Wire values mirror the server enum EXACTLY
/// (`src/invoice.rs` list/status: `unpaid`, `in_progress`, `partially_paid`,
/// `paid`, `underpaid`, `overpaid`, `expired`, `cancelled`).
enum InvoiceStatus {
  unpaid,
  inProgress,
  partiallyPaid,
  paid,
  underpaid,
  overpaid,
  expired,
  cancelled;

  String get wire => switch (this) {
    InvoiceStatus.unpaid => 'unpaid',
    InvoiceStatus.inProgress => 'in_progress',
    InvoiceStatus.partiallyPaid => 'partially_paid',
    InvoiceStatus.paid => 'paid',
    InvoiceStatus.underpaid => 'underpaid',
    InvoiceStatus.overpaid => 'overpaid',
    InvoiceStatus.expired => 'expired',
    InvoiceStatus.cancelled => 'cancelled',
  };

  /// Tolerant reader: an unknown/absent wire value maps to [unpaid] rather than
  /// throwing, so a future server status cannot crash an older binary. (The
  /// terminal-status checks below simply treat an unknown status as non-terminal
  /// and keep polling.)
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
      _ => InvoiceStatus.unpaid,
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
    InvoiceStatus.partiallyPaid => false,
  };
}
