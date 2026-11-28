import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/catalogue.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:silent/silent.dart';
import 'package:startup/startup.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

import '../../../../packages/secrets/test/support/open_inventory.dart';
import '../../../../packages/sync/test/support/regtest_wallet.dart'
    show regtestDescriptor;
import '../../../support/preferences_database.dart';
import '../support/overview_home_harness.dart';

final class _GatedConnection implements WalletConnectionPort {
  final gate = Completer<void>();
  int calls = 0;
  SyncFailure? failure;

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    calls++;
    await gate.future;
    if (failure case final error?) return Err(error);
    return Ok(
      const SyncCompletion(SyncMode.revealedScripts, Duration.zero) as T,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(BullSdk.init);

  test(
    'connection and storage sync failures retain their diagnostics',
    () async {
      final temp = await Directory.systemTemp.createTemp('foreground-errors-');
      final previous = log;
      log = Logger.replace(directory: temp);
      final connection = _GatedConnection()..gate.complete();
      final vector = regtestDescriptor();
      final sync = ForegroundWalletSynchronization(
        ElectrumSync(
          connections: connection,
          documentsDirectory: () async => temp.path,
          readRevision: (_) async => const Err(SyncNotFoundFailure()),
        ),
      );
      addTearDown(() async {
        try {
          await log.flush();
        } finally {
          log = previous;
          await temp.delete(recursive: true);
        }
      });
      connection.failure = const SyncConnectionFailure();
      expect(
        await sync.execute(vector),
        isA<Err<void, SyncFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<SyncConnectionFailure>(),
        ),
      );
      var rows = await log.readLogs();
      expect(rows.where((row) => row.contains('\tWARNING\t')), hasLength(1));
      expect(rows.join('\n'), contains('Electrum sync failed'));
      expect(rows.join('\n'), contains('category=connection'));
      expect(rows.join('\n'), isNot(contains('SEVERE')));
      connection.failure = const SyncStorageFailure();
      expect(
        await sync.execute(vector),
        isA<Err<void, SyncFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<SyncStorageFailure>(),
        ),
      );
      rows = await log.readLogs();
      expect(rows.where((row) => row.contains('\tSEVERE\t')), hasLength(1));
      expect(rows.join('\n'), contains('category=storage'));
    },
  );

  for (final refuseFirst in [true, false]) {
    test(
      refuseFirst
          ? 'one native hydration failure leaves its neighbour visible and Home total unknown'
          : 'real foreground start does not admit a new balance hydration',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'overview-native-admission-',
        );
        final previousLog = log;
        log = Logger.replace(directory: temp);
        addTearDown(() async {
          try {
            await log.flush();
          } finally {
            log = previousLog;
            await temp.delete(recursive: true);
          }
        });
        final previousDebugPrint = debugPrint;
        final readerAdmissions = <String>[];
        debugPrint = (message, {wrapWidth}) {
          if (message != null &&
              message.contains(
                'event=lease_acquire role=reader intent=snapshot',
              )) {
            readerAdmissions.add(message);
          }
          previousDebugPrint(message, wrapWidth: wrapWidth);
        };
        addTearDown(() => debugPrint = previousDebugPrint);
        final storage = await openFreshInventory(temp);
        final inventory = storage.inventory;
        final database = await createPreferencesDatabase();
        final preferences = PreferencesTesting.fromDao(
          PreferencesDao(database),
        );
        valueOf(await preferences.setIsSuperuser(true));
        valueOf(await preferences.setIsDevMode(true));
        valueOf(await preferences.setEnvironment(Environment.regtest));
        final vector = regtestDescriptor();
        final ids = [
          '${vector.origin}:regtest',
          'wpkh([73c5da0a/84h/1h/1h]):regtest',
        ];
        for (final id in ids) {
          valueOf(
            await inventory.registerWallet(
              watchOnlyWallet(
                id,
                network: 'bitcoinRegtest',
                external: vector.externalDescriptor,
                internal: vector.internalDescriptor,
              ),
            ),
          );
        }
        final connections = _GatedConnection();
        var hydrations = 0;
        final sync = ElectrumSync(
          connections: connections,
          documentsDirectory: () async => '${temp.path}/native',
          readRevision: (_) async => const Err(SyncNotFoundFailure()),
        );
        final native = WalletNativeRuntime.open(
          catalog: SecretsWalletCatalog.foreground(inventory),
          reserved: const NoReservedAddresses(),
          inputReservations: NoInputReservations(),
          deleteCatalogEntry: SecretsWalletCatalog.removal(inventory),
          sync: sync,
          documentsDirectory: () async => '${temp.path}/native',
          freezes: MemoryFreezeStore(),
          connections: connections,
          beforeBalanceHydration: () async {
            hydrations++;
            if (refuseFirst && hydrations == 1) {
              throw const FileSystemException('fixture unavailable');
            }
          },
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
        final pass = FakeHomeSync();
        final amounts = FakeAmountDisplayPreferences();
        final controller = OverviewHomeController(
          catalogue: CatalogueHomeSource(catalogue),
          sync: pass,
          amountDisplay: OverviewAmountDisplay(amounts),
          ongoingSwaps: FakeOngoingSwaps(),
          swapServerCheck: FakeSwapServerCheck(),
          readBackupWarning: () async => false,
          readPhysicalBackup: (_) async => false,
          proxyNeedsAttention: () async => false,
          silentHome: SilentHomeObservation(FakeSilent()),
          syncStarted: sync.runsStarted.map(
            (event) => (key: event.key, runId: event.runId),
          ),
          syncFinished: sync.finished.map((event) => event.key),
          electrumResults: const Stream.empty(),
        );
        addTearDown(() async {
          if (!connections.gate.isCompleted) connections.gate.complete();
          await controller.close();
          await catalogue.close();
          await startup.dispose();
          valueOf(await native.close());
          await amounts.close();
          await pass.close();
          await preferences.close();
          await database.close();
          await inventory.close();
          await storage.admission.close();
        });
        await startup.start();
        bool ready() =>
            catalogue.snapshot.rows.length == 2 &&
            hydrations >= 2 &&
            catalogue.snapshot.rows
                    .where((row) => row.balanceSat != null)
                    .length ==
                (refuseFirst ? 1 : 2);
        for (var i = 0; i < 500 && !ready(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(ready(), isTrue);
        await flushEvents();
        final rows = catalogue.snapshot.rows;
        expect(rows.map((row) => row.entry.key.id).toSet(), ids.toSet());
        if (refuseFirst) {
          final unavailable = rows.singleWhere((row) => row.balanceSat == null);
          final available = rows.singleWhere((row) => row.balanceSat != null);
          expect(unavailable.revision, isNull);
          expect(available.balanceSat, BigInt.zero);
          expect(available.revision, isNotNull);
          expect(controller.current.rows, hasLength(2));
          expect(controller.current.totalSat, isNull);
        } else {
          final key = rows.first.entry.key;
          final descriptor = switch (await SecretsWalletCatalog.foreground(
            inventory,
          ).find(key)) {
            Ok(:final value) => value,
            Err(:final failure) => fail(failure.logCode),
          };
          final before = hydrations;
          final admissionsBefore = readerAdmissions.length;
          expect(admissionsBefore, greaterThanOrEqualTo(2));
          final started = sync.started.first;
          final finished = sync.finished.first;
          final syncing = ForegroundWalletSynchronization(
            sync,
            native: native,
          ).execute(descriptor);
          expect(await started, key);
          await flushEvents();
          expect(connections.calls, 1);
          expect(hydrations, before);
          expect(readerAdmissions.length, admissionsBefore);
          expect(
            controller.current.rows
                .singleWhere((row) => row.selection.key == key)
                .isSyncing,
            isTrue,
          );
          connections.gate.complete();
          expect(await syncing, isA<Ok>());
          expect((await finished).key, key);
          await flushEvents();
          expect(hydrations, before);
          expect(readerAdmissions.length, admissionsBefore);
          expect(
            controller.current.rows
                .singleWhere((row) => row.selection.key == key)
                .isSyncing,
            isFalse,
          );
          final beforeFailures = hydrations;
          final admissionsBeforeFailures = readerAdmissions.length;
          for (final failure in const <SyncFailure>[
            SyncConnectionFailure(),
            SyncStorageFailure(),
          ]) {
            connections.failure = failure;
            final result = await ForegroundWalletSynchronization(
              sync,
              native: native,
            ).execute(descriptor);
            expect(
              result,
              isA<Err<void, SyncFailure>>().having(
                (result) => result.failure,
                'failure',
                same(failure),
              ),
            );
          }
          await flushEvents();
          expect(hydrations, beforeFailures);
          expect(readerAdmissions.length, admissionsBeforeFailures);
        }
      },
    );
  }
}
