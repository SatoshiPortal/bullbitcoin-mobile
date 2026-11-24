import 'dart:typed_data';

import 'package:primitives/primitives.dart';

/// One transaction a targeted pass must be able to judge: what it pays and
/// what it spends, never its id alone.
///
/// The wallet resolves these to its own derivation indices — the outputs it
/// owns by script, the spent outpoints it has ever owned, spent included — and
/// covers exactly those. A pass built from a target asks the server about
/// scripts, never about [txid], so the id here only names the answer.
///
/// A target that does not name a real transaction is rejected when it is
/// built, before any native call can mutate a wallet: [txid] and every spent
/// outpoint's `txId` in [spentOutpoints] must be exactly 64 lowercase
/// hexadecimal characters. Native ids are lowercase and a pass's answers are
/// keyed by the supplied id, so an uppercase id is rejected rather than
/// normalized into a different key. Script bytes need no such check, because a
/// wallet that does not derive them simply owns nothing there.
final class SyncTransactionTarget {
  static final _txidPattern = RegExp(r'^[0-9a-f]{64}$');

  final String txid;
  final List<Uint8List> outputScripts;
  final List<Outpoint> spentOutpoints;

  SyncTransactionTarget({
    required this.txid,
    List<Uint8List> outputScripts = const <Uint8List>[],
    List<Outpoint> spentOutpoints = const <Outpoint>[],
  }) : outputScripts = List<Uint8List>.unmodifiable(outputScripts),
       spentOutpoints = List<Outpoint>.unmodifiable(spentOutpoints) {
    _requireTxid(txid, 'txid');
    for (final outpoint in this.spentOutpoints) {
      _requireTxid(outpoint.txId, 'spentOutpoints.txId');
    }
  }

  static void _requireTxid(String value, String name) {
    if (!_txidPattern.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        name,
        'must be exactly 64 lowercase hexadecimal characters',
      );
    }
  }
}
