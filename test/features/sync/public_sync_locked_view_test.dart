import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:background_tasks/src/data/background_wallet_sync_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show ElectrumSync;

import '../../support/inventory_fixture.dart';

/// Records what a public sync pass asks of its Electrum transport and answers
/// from the test, so no real server is involved.
final class _Transport implements WalletConnectionPort {
  final runs = <Network>[];
  final bool refuse;

  _Transport({this.refuse = false});

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) {
    runs.add(network);
    if (refuse) return Future.value(const Err(SyncConnectionFailure()));
    return operation(
      WalletConnection(
        url: 'tcp://controlled.invalid:50001',
        timeout: const Duration(seconds: 1),
        retry: 0,
        stopGap: 20,
        validateDomain: false,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late FakeSecureStoragePlatform keystore;
  late InventoryFixture fixture;
  late BackgroundWalletDescriptors background;

  /// A protected view holding one public wallet, then locked.
  Future<void> prepare({required bool backgroundAccess}) async {
    directory = await Directory.systemTemp.createTemp('public-sync-locked-');
    // The seed keystore: every read of it is counted.
    keystore = FakeSecureStoragePlatform()..install();
    fixture = await InventoryFixture.open(directory);
    expect(
      await fixture.inventory.registerWallet(
        const RegisteredWallet(
          id: 'wpkh([c258d2e4/84h/1h/0h])',
          network: 'bitcoinTestnet',
          masterFingerprint: 'c258d2e4',
          secretFingerprint: null,
          signer: 'none',
          xpub: 'public-key-marker',
          externalDescriptor: 'wpkh([c258d2e4/84h/1h/0h]tpubDDYkZojQFQjht8Tm4jsS3iuEmKjTiEGjG6KnuFNKKJb5A6ZUCUZKdvLdSDWofKi4ToRCwb9poe1XdqfUnP4jaJjCB2Zwv11ZLgSbnZSNecE/0/*)',
          internalDescriptor: 'wpkh([c258d2e4/84h/1h/0h]tpubDDYkZojQFQjht8Tm4jsS3iuEmKjTiEGjG6KnuFNKKJb5A6ZUCUZKdvLdSDWofKi4ToRCwb9poe1XdqfUnP4jaJjCB2Zwv11ZLgSbnZSNecE/1/*)',
          label: '',
          birthday: null,
          isDefault: false,
        ),
      ),
      isA<Ok>(),
    );
    expect(
      await fixture.inventory.setBackgroundEnabled(backgroundAccess),
      isA<Ok>(),
    );
    expect(await fixture.inventory.setCredential('1234'), isA<Ok>());
    expect(await fixture.inventory.lock(), isTrue);
    background = switch (await BackgroundWalletDescriptors.open(
      file: File('${directory.path}/test-secrets.sqlite'),
      admission: fixture.admission,
    )) {
      Ok(:final value) => value,
      Err() => throw StateError('background descriptors unavailable'),
    };
  }

  tearDown(() async {
    await background.close();
    await fixture.inventory.close();
    await fixture.admission.close();
    await directory.delete(recursive: true);
  });

  test('a locked view lists its public wallets to a simulated pass and reads no seed', () async {
    await prepare(backgroundAccess: true);
    expect(fixture.inventory.isLocked, isTrue);
    // The locked foreground refuses its own catalog: nothing leaks through it.
    expect(
      await SecretsWalletCatalog.foreground(fixture.inventory).list(),
      isA<Err>(),
    );
    final baseline = keystore.reads;

    final catalog = SecretsWalletCatalog.background(background);
    final listed = await catalog.list();
    final wallets =
        (listed as Ok<List<PublicWalletDescriptor>, SyncFailure>).value;
    expect(wallets.map((wallet) => wallet.key.id), [
      'wpkh([c258d2e4/84h/1h/0h])',
    ]);

    // The pass opens its Electrum connection from the public descriptors.
    final transport = _Transport();
    for (final wallet in wallets) {
      final result = await transport.run<String>(
        network: wallet.key.network,
        operation: (connection) async => Ok(connection.url),
        mayRetry: (_) => false,
      );
      expect(result, isA<Ok>());
    }

    expect(transport.runs, [BitcoinNetwork.testnet]);
    expect(keystore.reads, baseline, reason: 'no seed was read');
  });

  test('BackgroundWalletSyncImpl runs the real ElectrumSync for a locked view and reads no seed', () async {
    await prepare(backgroundAccess: true);
    expect(fixture.inventory.isLocked, isTrue);
    final baseline = keystore.reads;
    final transport = _Transport(refuse: true);
    var revisionReads = 0;
    final sync = ElectrumSync(
      connections: transport,
      documentsDirectory: () async => directory.path,
      // A controlled revision: the wallet has none yet.
      readRevision: (_) async {
        revisionReads++;
        return const Err(SyncNotFoundFailure());
      },
    );
    final impl = BackgroundWalletSyncImpl(
      SecretsWalletCatalog.background(background),
      sync,
      collectIncoming: false,
    );
    final key = WalletKey(
      id: 'wpkh([c258d2e4/84h/1h/0h])',
      network: BitcoinNetwork.testnet,
    );

    final result = await impl.synchronize(
      key,
      allowInitialScan: true,
      discover: false,
    );

    // The pass reached its Electrum transport with the public descriptors
    // and nothing else; the controlled transport refused, so the native
    // wallet engine never ran in this host test.
    expect(
      (result as Err<BackgroundSyncOutcome, BackgroundSyncFailure>).failure,
      isA<BackgroundSyncConnectionFailure>(),
    );
    expect(transport.runs, [BitcoinNetwork.testnet]);
    expect(revisionReads, greaterThanOrEqualTo(0));
    expect(keystore.reads, baseline, reason: 'no seed was read');
  });

  test('a view without background access syncs nothing while locked', () async {
    await prepare(backgroundAccess: false);
    final catalog = SecretsWalletCatalog.background(background);
    final listed = await catalog.list();
    expect(
      (listed as Ok<List<PublicWalletDescriptor>, SyncFailure>).value,
      isEmpty,
    );
  });
}
