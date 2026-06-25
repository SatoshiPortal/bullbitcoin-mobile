import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/view_models/transaction_detail_view_model.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/transaction_section_contributor.dart';

/// Assembles a [TransactionDetailViewModel] by running every registered
/// [TransactionSectionContributor] that applies to the transaction.
///
/// Rows and callouts from all applicable contributors are concatenated in
/// ascending priority order (identity facets first, mechanism specifics
/// after). The header and progress are taken from the single highest-priority
/// applicable contributor, which guarantees one authoritative status — a
/// chain swap's on-chain lockup can no longer render a second, contradicting
/// status.
class TransactionDetailViewModelBuilder {
  const TransactionDetailViewModelBuilder(this._contributors);

  final List<TransactionSectionContributor> _contributors;

  TransactionDetailViewModel build(Transaction tx, TxPresentDeps deps) {
    final applicable = _contributors.where((c) => c.appliesTo(tx)).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final rows = <TxDetailRow>[];
    final callouts = <TxCallout>[];
    TxHeaderView? header;
    TxProgressView? progress;

    for (final contributor in applicable) {
      rows.addAll(contributor.rows(tx, deps));
      callouts.addAll(contributor.callouts(tx, deps));
      // Ascending priority: later (higher-priority) contributors overwrite.
      final h = contributor.header(tx, deps);
      if (h != null) header = h;
      final p = contributor.progress(tx, deps);
      if (p != null) progress = p;
    }

    return TransactionDetailViewModel(
      header: header ?? _fallbackHeader(tx, deps),
      progress: progress,
      rows: rows,
      callouts: callouts,
    );
  }

  TxHeaderView _fallbackHeader(Transaction tx, TxPresentDeps deps) {
    return TxHeaderView(
      isIncoming: tx.isIncoming,
      isTransfer: false,
      statusLabel: tx.isIncoming
          ? deps.loc.transactionFilterReceive
          : deps.loc.transactionFilterSend,
      amount: TxAmountView(sats: tx.amountSat),
    );
  }
}
