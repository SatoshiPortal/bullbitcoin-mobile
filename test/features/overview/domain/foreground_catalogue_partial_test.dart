import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/catalogue.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:startup/startup.dart';
import 'package:sync/inventory.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

import '../../../../packages/secrets/test/support/open_inventory.dart';
import '../../../../packages/sync/test/support/connections.dart';
import '../../../../packages/sync/test/support/regtest_wallet.dart'
    show regtestDescriptor;
import '../../../support/preferences_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(BullSdk.init);

  test(
    'malformed inventory row does not hide readable membership and receipts',
    () async {
      final temp = await Directory.systemTemp.createTemp('partial-catalogue-');
      final storage = await openFreshInventory(temp);
      final inventory = storage.inventory;
      final database = await createPreferencesDatabase();
      final preferences = PreferencesTesting.fromDao(PreferencesDao(database));
      valueOf(await preferences.setIsSuperuser(true));
      valueOf(await preferences.setIsDevMode(true));
      valueOf(await preferences.setEnvironment(Environment.regtest));
      final vector = regtestDescriptor();
      final good = '${vector.origin}:regtest';
      const bad = 'invalid:regtest';
      valueOf(
        await inventory.registerWallet(
          watchOnlyWallet(
            good,
            network: 'bitcoinRegtest',
            external: vector.externalDescriptor,
            internal: vector.internalDescriptor,
          ),
        ),
      );
      valueOf(
        await inventory.registerWallet(
          watchOnlyWallet(
            bad,
            network: 'bitcoinRegtest',
            external: vector.externalDescriptor,
            internal: vector.internalDescriptor,
          ),
        ),
      );
      final connections = FixtureConnections([]);
      final native = WalletNativeRuntime.open(
        catalog: SecretsWalletCatalog.foreground(inventory),
        reserved: const NoReservedAddresses(),
        inputReservations: NoInputReservations(),
        deleteCatalogEntry: SecretsWalletCatalog.removal(inventory),
        sync: ElectrumSync(
          connections: connections,
          documentsDirectory: () => throw StateError('Unexpected sync'),
          readRevision: (_) => throw StateError('Unexpected sync'),
        ),
        documentsDirectory: () async => '${temp.path}/native',
        freezes: MemoryFreezeStore(),
        connections: connections,
      );
      final balances = ForegroundBalanceStartup.mount(
        runtime: () => native,
        inventory: inventory,
        preferences: preferences,
      );
      final startup = ForegroundWalletStartup(
        initialize: native.initialize,
        startWatchers: () {},
        balances: balances,
      );
      final catalogue = OverviewCatalogue.mount(
        balances: balances.observation,
        inventory: inventory,
      );
      addTearDown(() async {
        await catalogue.close();
        await startup.dispose();
        valueOf(await native.close());
        await preferences.close();
        await database.close();
        await inventory.close();
        await storage.admission.close();
        await temp.delete(recursive: true);
      });
      await startup.start();
      for (
        var i = 0;
        i < 500 &&
            (catalogue.snapshot.status != OverviewCatalogueStatus.partial ||
                catalogue.snapshot.rows.isEmpty ||
                catalogue.snapshot.rows.single.balanceSat == null);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(catalogue.snapshot.status, OverviewCatalogueStatus.partial);
      expect(catalogue.snapshot.rows.map((row) => row.entry.key.id), [good]);
      expect(catalogue.snapshot.rows.single.balanceSat, BigInt.zero);
      expect(catalogue.snapshot.rows.single.revision, isNotNull);
      expect(connections.attempts, 0);
    },
  );
}
