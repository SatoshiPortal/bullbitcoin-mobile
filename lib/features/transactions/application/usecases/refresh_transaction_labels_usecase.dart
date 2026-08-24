import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';

/// Re-reads the labels of transactions that are already loaded.
///
/// Labels live in their own table and are joined onto a transaction at read
/// time, so one added or removed elsewhere is invisible to a list loaded
/// before the change. This redoes only that join: one local query, no chain
/// sync and no exchange call.
class RefreshTransactionLabelsUsecase {
  final LabelsFacade _labelsFacade;

  RefreshTransactionLabelsUsecase({required this._labelsFacade});

  /// Returns the list it was given when nothing changed, so the caller can
  /// skip emitting a new state.
  Future<List<Transaction>> execute(List<Transaction> transactions) async {
    // Only a wallet transaction carries labels, so an exchange-only list has
    // nothing to join and needs no read at all.
    if (!transactions.any((t) => t.walletTransaction != null)) {
      return transactions;
    }

    final labels = switch (await _labelsFacade.fetchAllOrFailure()) {
      Ok(:final value) => value,
      // A failed read is not "the labels are gone": leave the list alone
      // rather than blanking every row until the next full load.
      Err() => null,
    };
    if (labels == null) return transactions;

    final labelsByReference = <String, List<Label>>{};
    for (final label in labels) {
      labelsByReference.putIfAbsent(label.reference, () => []).add(label);
    }

    var changed = false;
    final refreshed = transactions.map((transaction) {
      final walletTransaction = transaction.walletTransaction;
      if (walletTransaction == null) return transaction;

      final labels =
          labelsByReference[walletTransaction.txId] ?? const <Label>[];
      if (_hasSameLabels(walletTransaction.labels, labels)) return transaction;

      changed = true;
      return transaction.copyWith(
        walletTransaction: walletTransaction.copyWith(labels: labels),
      );
    }).toList();

    return changed ? refreshed : transactions;
  }

  bool _hasSameLabels(List<Label> current, List<Label> latest) {
    if (current.length != latest.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i].id != latest[i].id) return false;
    }
    return true;
  }
}
