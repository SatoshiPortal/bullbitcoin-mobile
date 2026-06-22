import 'package:bb_mobile/features/labels/labels_facade.dart';

/// Protocol-agnostic, UI-facing description of a transaction details screen.
///
/// Built by [TransactionDetailViewBuilder] from one or more
/// [TransactionSectionContributor]s and rendered by the transaction details
/// widgets. The widgets depend only on this view model, never on the concrete
/// domain entities (Swap, Order, Payjoin, WalletTransaction).
class TransactionDetailView {
  const TransactionDetailView({
    required this.header,
    this.progress,
    this.rows = const [],
    this.callouts = const [],
  });

  final TxHeaderView header;

  /// Present only for mechanisms with a multi-step flow (e.g. swaps). Rendered
  /// as the single authoritative status row: collapsed as a one-line summary,
  /// expanded as the step-by-step view.
  final TxProgressView? progress;

  final List<TxDetailRow> rows;
  final List<TxCallout> callouts;
}

enum TxStatusTone { normal, error, errorMuted }

class TxHeaderView {
  const TxHeaderView({
    required this.isIncoming,
    required this.isTransfer,
    required this.statusLabel,
    required this.amount,
    this.tone = TxStatusTone.normal,
  });

  final bool isIncoming;

  /// Whether to show the swap/transfer direction badge (chain swaps).
  final bool isTransfer;

  /// The single, authoritative headline status. Because both the headline and
  /// the status row derive from the same view, they can never disagree.
  final String statusLabel;
  final TxStatusTone tone;
  final TxAmountView amount;
}

class TxAmountView {
  const TxAmountView({this.sats = 0, this.fiatAmount, this.fiatCurrency});

  final int sats;
  final double? fiatAmount;
  final String? fiatCurrency;

  bool get isFiat => fiatAmount != null && fiatCurrency != null;
}

enum TxProgressState { inProgress, completed, failed }

class TxProgressView {
  const TxProgressView({
    required this.label,
    required this.summaryLabel,
    required this.steps,
    required this.currentStep,
    required this.state,
    this.detailMessage,
  });

  /// Row label, e.g. "Transfer Status" / "Swap Status".
  final String label;

  /// Collapsed one-liner, e.g. "In progress · Step 2 of 4" or "Completed".
  final String summaryLabel;

  /// Ordered step labels shown in the expanded step view.
  final List<String> steps;

  /// 0-based index of the current step, or -1 when failed/expired.
  final int currentStep;
  final TxProgressState state;

  /// Longer human description shown under the steps when expanded.
  final String? detailMessage;
}

/// A single labelled row. [expandedRows] (if any) are revealed behind the row's
/// own expand toggle — the per-row "advanced detail" mechanism.
class TxDetailRow {
  const TxDetailRow({
    required this.label,
    required this.value,
    this.copyValue,
    this.expandedRows = const [],
    this.expandedNote,
  });

  final String label;
  final TxValue value;
  final String? copyValue;
  final List<TxDetailRow> expandedRows;

  /// Optional explanatory line shown above [expandedRows] when expanded
  /// (e.g. "Fees are deducted from the amount you receive").
  final String? expandedNote;
}

/// Typed cell value. The renderer maps each variant to the right existing
/// widget (Text / CurrencyText / TransactionViewer / AddressViewer /
/// LabelsTableItem), so contributors stay free of widget and BuildContext
/// dependencies.
sealed class TxValue {
  const TxValue();
}

class TxText extends TxValue {
  const TxText(this.text);
  final String text;
}

class TxAmount extends TxValue {
  const TxAmount(this.sats);
  final int sats;
}

class TxFiat extends TxValue {
  const TxFiat(this.amount, this.currency);
  final double amount;
  final String currency;
}

class TxId extends TxValue {
  const TxId(
    this.txid, {
    required this.isLiquid,
    required this.isTestnet,
    this.unblindedUrl,
  });
  final String txid;
  final bool isLiquid;
  final bool isTestnet;
  final String? unblindedUrl;
}

class TxAddress extends TxValue {
  const TxAddress(this.address);
  final String address;
}

class TxLabels extends TxValue {
  const TxLabels(this.labels);
  final List<Label> labels;
}

enum TxCalloutTone { info, warning, error }

/// A highlighted info/warning block (the swap status box becomes one of these,
/// and future mechanisms emit their own).
class TxCallout {
  const TxCallout({
    required this.tone,
    required this.title,
    required this.body,
    this.footnote,
    this.infoCardBody,
  });

  final TxCalloutTone tone;
  final String title;
  final String body;

  /// Italic supplementary line shown under [body].
  final String? footnote;

  /// When set, an additional emphasised info card is shown below the box
  /// (e.g. the "do not uninstall / open within 24h" swap warning).
  final String? infoCardBody;
}
