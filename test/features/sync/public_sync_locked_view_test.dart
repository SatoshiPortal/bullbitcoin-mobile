import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';

import '../../support/inventory_fixture.dart';

/// Records what a public sync pass asks of its Electrum transport and answers
/// from the test, so no real server is involved.
final class _Transport implements WalletConnectionPort {
  final runs = <Network>[];

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) {
    runs.add(network);
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
          id: 'wpkh([01234567/84h/1h/0h])',
          network: 'bitcoinTestnet',
          masterFingerprint: '01234567',
          secretFingerprint: null,
          signer: 'none',
          xpub: 'public-key-marker',
          externalDescriptor: 'wpkh(public/test/0)',
          internalDescriptor: 'wpkh(public/test/1)',
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

  test('a locked view still syncs its public wallets and reads no seed', () async {
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
      'wpkh([01234567/84h/1h/0h])',
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
