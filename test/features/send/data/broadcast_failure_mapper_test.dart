import 'package:electrum/setup.dart';
import 'package:bb_mobile/features/send/data/broadcast_failure_mapper.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart';

// The native causes and the servers' replies are classified in sync
// (packages/sync/test/chain/broadcast_replies_test.dart); this is the mapping
// of its closed vocabulary to the categories the screens read.
void main() {
  final cases = <(SyncFailure, BroadcastFailureCategory)>[
    (const SyncBroadcastRejectedFailure(), BroadcastFailureCategory.rejected),
    (
      const SyncAlreadyInChainFailure(),
      BroadcastFailureCategory.alreadyInChain,
    ),
    (const SyncConnectionFailure(), BroadcastFailureCategory.connection),
    (
      const SyncUnauthorizedNetworkFailure(),
      BroadcastFailureCategory.authorization,
    ),
    // Mixed servers and unclassified replies: the transaction may have been
    // relayed, so it is never read as rejected.
    (const SyncOutcomeUnknownFailure(), BroadcastFailureCategory.unexpected),
    (
      const SyncInvalidTransactionFailure(),
      BroadcastFailureCategory.unexpected,
    ),
    (
      const SyncUnsupportedNetworkFailure(),
      BroadcastFailureCategory.unexpected,
    ),
    (const SyncBusyFailure(), BroadcastFailureCategory.unexpected),
  ];
  for (final (failure, expected) in cases) {
    test('${failure.logCode} reads ${expected.name}', () {
      expect(broadcastFailureCategory(failure), expected);
    });
  }

  test('a categorized exception keeps its category', () {
    for (final category in BroadcastFailureCategory.values) {
      expect(
        mapBroadcastFailure(CategorizedBroadcastException(category)),
        category,
      );
    }
  });

  test('anything else is unexpected, whatever its text says', () {
    for (final error in [
      Exception('{"code":-26}'),
      AllElectrumServersFailedException(const []),
      StateError('sendrawtransaction RPC error -27: '),
    ]) {
      expect(mapBroadcastFailure(error), BroadcastFailureCategory.unexpected);
    }
  });
}
