import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart';
import 'package:secrets/secrets.dart' show SecretFailure, StoreSecretFailure;
import 'package:secrets/storage.dart';

import 'support/open_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SecretsInventory inventory;
  late WalletCatalogueSignal signal;
  late List<WalletCatalogueStamp?> events;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('catalogue-signal-');
    final fixture = await openFreshInventory(dir);
    inventory = fixture.inventory;
    signal = inventory.walletCatalogue;
    events = [];
    final subscription = signal.changes.listen(
      (_) => events.add(signal.capture()),
    );
    addTearDown(() async {
      await subscription.cancel();
      await inventory.close();
      await fixture.admission.close();
      await dir.delete(recursive: true);
    });
  });

  WalletCatalogueStamp capture() {
    final stamp = signal.capture();
    if (stamp == null) throw StateError('Expected an active inventory grant');
    return stamp;
  }

  test('commit invalidates a captured read before completion; compensation invalidates again', () async {
    final before = capture();
    final prepared = Completer<void>();
    final release = Completer<void>();
    final registering = inventory.registerWallet(
      watchOnlyWallet('b-bitcoin'),
      prepareProperties: (_) async {
        prepared.complete();
        await release.future;
        return const Ok(null);
      },
    );
    await prepared.future;
    expect(signal.isCurrent(before), isTrue);
    expect(events, isEmpty);
    release.complete();
    valueOf(await registering);
    expect(signal.isCurrent(before), isFalse);
    final registered = capture();
    expect(registered.grant, same(before.grant));
    expect(registered.generation, before.generation + 1);
    expect(valueOf(await inventory.listWallets()).single.id, 'b-bitcoin');

    final waiting = Completer<void>();
    final reading = inventory.readInSession(() async {
      final rows = valueOf(await inventory.listWallets());
      await waiting.future;
      return rows;
    });
    await pumpEventQueue();
    valueOf(await inventory.removeWallet('b-bitcoin'));
    expect(signal.isCurrent(registered), isFalse);
    waiting.complete();
    expect(valueOf(await reading).single.id, 'b-bitcoin');
    expect(valueOf(await inventory.listWallets()), isEmpty);
    expect(capture().generation, before.generation + 2);
    expect(events, hasLength(2));
  });

  test(
    'rollback, duplicate, missing removal and property no-op never advance',
    () async {
      final before = capture();
      final wallet = watchOnlyWallet('w');
      expect(
        await inventory.registerWallet(
          wallet,
          prepareProperties: (_) async =>
              const Err(StoreSecretFailure('test refusal')),
        ),
        isA<Err>(),
      );
      expect(valueOf(await inventory.listWallets()), isEmpty);
      expect(signal.isCurrent(before), isTrue);
      valueOf(await inventory.registerWallet(wallet));
      final registered = capture();
      expect(await inventory.registerWallet(wallet), isA<Err>());
      expect(await inventory.removeWallet('missing'), isA<Err>());
      valueOf(
        await inventory.setWalletProperties(
          id: wallet.id,
          label: null,
          birthday: null,
          isDefault: false,
        ),
      );
      expect(signal.isCurrent(registered), isTrue);
      valueOf(
        await inventory.setWalletProperties(
          id: wallet.id,
          label: 'Savings',
          birthday: null,
          isDefault: true,
        ),
      );
      expect(capture().generation, registered.generation + 1);
      await pumpEventQueue();
      expect(events, hasLength(2));
    },
  );

  test(
    'lock rolls back blocked registration and activate replaces only the grant',
    () async {
      final before = capture();
      final entered = Completer<void>();
      final release = Completer<void>();
      final pending = inventory.registerWallet(
        watchOnlyWallet('w'),
        prepareProperties: (_) async {
          entered.complete();
          await release.future;
          return const Ok(null);
        },
      );
      await entered.future;
      final locking = inventory.lock();
      expect(signal.capture(), isNull);
      expect(signal.isCurrent(before), isFalse);
      release.complete();
      expect(await pending, isA<Err>());
      expect(await locking, isTrue);
      valueOf(await inventory.resumeUnprotected());
      final reentered = capture();
      expect(reentered.generation, before.generation);
      expect(reentered.grant, isNot(same(before.grant)));
      expect(valueOf(await inventory.listWallets()), isEmpty);
      final views = inventory.openedViews;
      if (views == null) throw StateError('Expected the default opened view');
      final activating = views.activate(const ViewId('all'));
      expect(signal.isCurrent(reentered), isFalse);
      valueOf(await activating);
      expect(capture().generation, before.generation);
      expect(events, hasLength(3));
    },
  );

  test('only effective restoration invalidates and mixed networks retain historical order', () async {
    const bitcoinId = 'wpkh([01234567/84h/1h/0h])';
    final btc = watchOnlyWallet(bitcoinId);
    valueOf(
      await inventory.registerWallet(
        watchOnlyWallet('a-liquid', network: 'liquidTestnet'),
      ),
    );
    valueOf(await inventory.registerWallet(btc));
    valueOf(
      await inventory.registerWallet(
        watchOnlyWallet('z-liquid', network: 'liquidTestnet'),
      ),
    );
    expect(valueOf(await inventory.listWallets()).map((row) => row.id), [
      'a-liquid',
      bitcoinId,
      'z-liquid',
    ]);
    final session = valueOf(await inventory.backupSession());
    final before = capture();
    Future<({bool label, bool birthday})> restore() async =>
        valueOf<({bool label, bool birthday}), SecretFailure>(
          await inventory.restorePublicWalletProperties(
            session: session,
            network: BitcoinNetwork.testnet,
            external: btc.externalDescriptor,
            internal: btc.internalDescriptor,
            label: 'Recovered',
            birthday: DateTime.utc(2020),
          ),
        );
    expect(await restore(), (label: true, birthday: true));
    expect(signal.isCurrent(before), isFalse);
    final restored = capture();
    expect(await restore(), (label: false, birthday: false));
    expect(signal.isCurrent(restored), isTrue);
    expect(restored.generation, before.generation + 1);
  });
}
