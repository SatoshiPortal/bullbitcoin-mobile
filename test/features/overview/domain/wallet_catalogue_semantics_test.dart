import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/catalogue.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:startup/startup.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

import '../../../../packages/secrets/test/support/open_inventory.dart';

final class _FailureInventory extends Fake implements WalletInventory {
  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) async => const Err(StoreSecretFailure('private disk diagnostic'));
}

class _Preferences extends Mock implements Preferences {}

final class _Offline implements WalletConnectionPort {
  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) => throw StateError('Unexpected network access');
}

final class _Reserved implements ReservedAddressPort {
  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

final class _InputReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real inventory orders default Bitcoin, default Liquid, then binary IDs',
    () async {
      final dir = await Directory.systemTemp.createTemp('overview-order-');
      final fixture = await openFreshInventory(dir);
      final inventory = fixture.inventory;
      final startup = ForegroundBalanceStartup.testing(
        catalogue: inventory.walletCatalogue,
        session: inventory.foregroundSession,
        transitions: const Stream<bool>.empty(),
        environmentChanging: () => false,
        readEnvironment: () async => NetworkEnv.regtest,
        select: (_) async => const Ok([]),
        revisions: () => const Stream<WalletRevisionState>.empty(),
        capture: (_, _, {catalogue}) => null,
        demand: (_) async => const Err(SyncStorageFailure()),
      );
      final overview = OverviewCatalogue.mount(
        balances: startup.observation,
        inventory: inventory,
      );
      addTearDown(() async {
        await overview.close();
        await startup.dispose();
        await inventory.close();
        await fixture.admission.close();
        await dir.delete(recursive: true);
      });
      const bitcoinDefault = 'wpkh([dddddddd/84h/1h/0h]):regtest';
      const liquidDefault = 'elwpkh([eeeeeeee/84h/1h/0h]):regtest';
      const first = 'wpkh([aaaaaaaa/84h/1h/0h]):regtest';
      const last = 'wpkh([bbbbbbbb/84h/1h/0h]):regtest';
      const bmp = 'wpkh([cccccccc/84h/1h/0h])\uE000:regtest';
      const supplementary = 'wpkh([cccccccc/84h/1h/0h])\u{10000}:regtest';
      for (final (id, liquid, isDefault) in [
        (last, false, false),
        (supplementary, false, false),
        (first, false, false),
        (bmp, false, false),
      ]) {
        valueOf(
          await inventory.registerWallet(
            watchOnlyWallet(
              id,
              network: liquid ? 'liquidRegtest' : 'bitcoinRegtest',
              external: liquid
                  ? 'ct(slip77(blinding),elwpkh(public))'
                  : 'wpkh(public)',
              internal: 'wpkh(change)',
              isDefault: isDefault,
            ),
          ),
        );
      }
      startup.admitUnlock();
      startup.initialized(const Err(SyncStorageFailure()));
      await until(overview, OverviewCatalogueStatus.ready);
      expect(overview.snapshot.rows.map((row) => row.entry.key.id), [
        first,
        last,
        bmp,
        supplementary,
      ]);
      for (final (id, liquid) in [
        (liquidDefault, true),
        (bitcoinDefault, false),
      ]) {
        valueOf(
          await inventory.registerWallet(
            watchOnlyWallet(
              id,
              network: liquid ? 'liquidRegtest' : 'bitcoinRegtest',
              external: liquid
                  ? 'ct(slip77(blinding),elwpkh(public))'
                  : 'wpkh(public)',
              internal: 'wpkh(change)',
              isDefault: true,
            ),
          ),
        );
      }
      if (overview.snapshot.rows.length != 6) {
        await overview.changes
            .firstWhere((_) => overview.snapshot.rows.length == 6)
            .timeout(const Duration(seconds: 5));
      }
      expect(overview.snapshot.rows.map((row) => row.entry.key.id), [
        bitcoinDefault,
        liquidDefault,
        first,
        last,
        bmp,
        supplementary,
      ]);
    },
  );

  test(
    'unreadable inventory does not expose a raw storage diagnostic',
    () async {
      final dir = await Directory.systemTemp.createTemp('overview-unreadable-');
      final fixture = await openFreshInventory(dir);
      final inventory = fixture.inventory;
      final startup = ForegroundBalanceStartup.testing(
        catalogue: inventory.walletCatalogue,
        session: inventory.foregroundSession,
        transitions: const Stream<bool>.empty(),
        environmentChanging: () => false,
        readEnvironment: () async => NetworkEnv.regtest,
        select: (_) async => const Ok([]),
        revisions: () => const Stream<WalletRevisionState>.empty(),
        capture: (_, _, {catalogue}) => null,
        demand: (_) async => const Err(SyncStorageFailure()),
      );
      final overview = OverviewCatalogue.mount(
        balances: startup.observation,
        inventory: _FailureInventory(),
      );
      addTearDown(() async {
        await overview.close();
        await startup.dispose();
        await inventory.close();
        await fixture.admission.close();
        await dir.delete(recursive: true);
      });
      startup.admitUnlock();
      startup.initialized(const Err(SyncStorageFailure()));
      await until(overview, OverviewCatalogueStatus.unreadable);
      expect(overview.snapshot.rows, isEmpty);
      expect(
        overview.snapshot.toString(),
        isNot(contains('private disk diagnostic')),
      );
    },
  );

  test(
    'failed environment read is unreadable without leaking its diagnostic',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'overview-environment-',
      );
      final fixture = await openFreshInventory(dir);
      final inventory = fixture.inventory;
      final preferences = _Preferences();
      when(() => preferences.environmentTransitions)
          .thenAnswer((_) => const Stream<bool>.empty());
      when(() => preferences.isEnvironmentChanging).thenReturn(false);
      when(preferences.readActiveEnvironment).thenAnswer(
        (_) async =>
            const Err(PreferencesReadFailure('private disk diagnostic')),
      );
      final offline = _Offline();
      final runtime = WalletNativeRuntime.open(
        catalog: NoCatalog(),
        reserved: _Reserved(),
        inputReservations: _InputReservations(),
        deleteCatalogEntry: (_) async => const Ok(null),
        sync: ElectrumSync(
          connections: offline,
          documentsDirectory: () async => dir.path,
          readRevision: (_) async => const Err(SyncNotFoundFailure()),
        ),
        documentsDirectory: () async => dir.path,
        freezes: MemoryFreezeStore(),
        connections: offline,
      );
      final startup = ForegroundBalanceStartup.mount(
        runtime: () => runtime,
        inventory: inventory,
        preferences: preferences,
      );
      final overview = OverviewCatalogue.mount(
        balances: startup.observation,
        inventory: inventory,
      );
      addTearDown(() async {
        await overview.close();
        await startup.dispose();
        await runtime.close();
        await inventory.close();
        await fixture.admission.close();
        await dir.delete(recursive: true);
      });
      startup.admitUnlock();
      startup.initialized(const Err(SyncStorageFailure()));
      await until(overview, OverviewCatalogueStatus.unreadable);
      expect(overview.snapshot.rows, isEmpty);
      expect(
        overview.snapshot.toString(),
        isNot(contains('private disk diagnostic')),
      );
      verify(preferences.readActiveEnvironment).called(1);
    },
  );
}

Future<void> until(
  OverviewCatalogue catalogue,
  OverviewCatalogueStatus status,
) async {
  if (catalogue.snapshot.status == status) return;
  await catalogue.changes
      .firstWhere((_) => catalogue.snapshot.status == status)
      .timeout(const Duration(seconds: 5));
}
