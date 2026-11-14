import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/wallet_projections.dart';
import 'package:sync/src/public/sync.dart' show walletOver;
import 'package:sync/sync.dart';

import 'support/projection_fakes.dart';
import 'package:sync/src/testing/test_wallets.dart' show MemoryFreezes;

void main() {
  final key = WalletKey(id: 'demand', network: BitcoinNetwork.testnet);
  late ScriptedRevisions revisions;
  late ScriptedSource source;
  late WalletProjections projections;

  setUp(() {
    revisions = ScriptedRevisions(key);
    source = ScriptedSource(revisions);
    projections = WalletProjections(
      freezes: MemoryFreezes(),
      revisions: revisions,
      changes: revisions.changes.stream,
      source: source,
    );
  });
  tearDown(() => projections.close());

  test('an address watched before the first load is served once it is '
      'published, without hydrating per subscriber', () async {
    final wallet = walletOver(projections, key, 0);
    final first = wallet.addresses.at(40).watch();
    final second = wallet.addresses.at(40).watch();
    final firstReady = first.firstWhere(
      (value) => value.status == ValueStatus.ready,
    );
    final secondReady = second.firstWhere(
      (value) => value.status == ValueStatus.ready,
    );
    await Future<void>.delayed(Duration.zero);
    // Subscribing records the demand; it neither loads nor derives.
    expect(source.maps, 0);
    expect(source.derives, 0);

    expect(await wallet.load(), isA<Ok<WalletRevision, SyncFailure>>());
    for (final ready in [firstReady, secondReady]) {
      final value = await ready.timeout(const Duration(seconds: 2));
      expect(value.data?.address, 'addr-external-40');
    }
    expect(source.maps, 1);
    expect(source.derives, 1);
  });
}
