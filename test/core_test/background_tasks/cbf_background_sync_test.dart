import 'package:bb_mobile/cbf_lifecycle.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'dart:ui' show IsolateNameServer;
import 'package:bb_mobile/core/background_tasks/cbf_owner_registry.dart';
import 'package:bb_mobile/core/background_tasks/cbf_background_sync.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Facade extends Mock implements WalletTransactionSyncFacade {}

class _Settings extends Mock implements SettingsRepository {}

class _Metadata extends Mock implements WalletMetadataDatasource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a background name collision leaves the owning run untouched', () async {
    const name = 'bull.cbf.background.policy';
    final stopRequested = Completer<void>();
    var stopRequests = 0;
    final owner = await CbfOwnerRegistration.acquire(
      name,
      onStop: () async {
        stopRequests++;
        if (!stopRequested.isCompleted) stopRequested.complete();
        return false;
      },
    );
    if (owner == null) fail('The test must own the background name');
    final identity = IsolateNameServer.lookupPortByName(name);
    final facade = _Facade();
    try {
      final candidate = CbfBackgroundSync(
        routing: BitcoinSyncRouting(
          facade: facade,
          settings: _Settings(),
          tor: () => throw StateError('unused'),
        ),
        wallets: () async => throw StateError('must not enumerate'),
        deadline: () => DateTime.now().toUtc().add(const Duration(seconds: 5)),
      );
      final result = await candidate.synchronize(
        const WalletNetworkKey('public', 'bitcoin', 'mainnet'),
      );
      expect((result as Err).failure, isA<WalletSyncDeferredFailure>());
      // Give a mistakenly fire-and-forget stop a chance to reach its owner.
      await Future.any([
        stopRequested.future,
        Future<void>.delayed(const Duration(milliseconds: 100)),
      ]);
      expect(stopRequests, 0);
      expect(IsolateNameServer.lookupPortByName(name), identity);
      verifyZeroInteractions(facade);
    } finally {
      expect(await owner.release(), isTrue);
    }
  });

  test(
    'sequential queue jobs share one complete CBF batch and deadline',
    () async {
      final facade = _Facade();
      final settings = _Settings();
      when(() => facade.stopCbfNodes()).thenAnswer((_) async => const Ok(null));
      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      final wallets = [
        for (final index in [0, 1, 2])
          WalletMetadataModel(
            id: 'wpkh([deadbeef/84h/0h/${index}h])',
            masterFingerprint: 'deadbeef',
            xpubFingerprint: 'public',
            isEncryptedVaultTested: false,
            isPhysicalBackupTested: false,
            xpub: 'public',
            externalPublicDescriptor: 'public-external-$index',
            internalPublicDescriptor: 'public-internal-$index',
            signer: Signer.none,
            isDefault: false,
            bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
          ),
      ];
      final limit = DateTime.now().toUtc().add(const Duration(minutes: 1));
      var runs = 0;
      when(
        () => facade.catchUpCbfWallets(any(), deadline: any(named: 'deadline')),
      ).thenAnswer((invocation) async {
        runs++;
        final registrations =
            invocation.positionalArguments.single
                as List<WalletSourceRegistration>;
        expect(registrations, hasLength(3));
        expect(
          invocation.namedArguments[#deadline],
          limit.subtract(const Duration(seconds: 3)),
        );
        for (final registration in registrations) {
          final config = registration.configuration as BdkCbfConfiguration;
          expect(config.electrumUrls, isEmpty);
          expect(config.deadline, limit.subtract(const Duration(seconds: 3)));
        }
        return {
          for (final registration in registrations)
            registration.key: const Err(InitialScanRequiredFailure()),
        };
      });
      final batch = CbfBackgroundSync(
        routing: BitcoinSyncRouting(
          facade: facade,
          settings: settings,
          tor: () => throw StateError('no direct fallback'),
          documentsDirectory: () async => '/tmp/public-cbf',
        ),
        wallets: () async => wallets,
        deadline: () => limit,
      );
      for (final wallet in wallets) {
        final result = await batch.synchronize(
          WalletNetworkKey(wallet.id, 'bitcoin', 'mainnet'),
        );
        expect((result as Err).failure, isA<InitialScanRequiredFailure>());
      }
      expect(runs, 1);
    },
  );
  test(
    'foreground invalidation stops the active headless service and cancels its batch',
    () async {
      final facade = _Facade(), settings = _Settings();
      final entered = Completer<void>();
      final pending = Completer<Map<WalletNetworkKey, CbfBackgroundOutcome>>();
      when(
        () => facade.catchUpCbfWallets(any(), deadline: any(named: 'deadline')),
      ).thenAnswer((_) async {
        entered.complete();
        return pending.future;
      });
      when(() => facade.stopCbfNodes()).thenAnswer((_) async {
        if (!pending.isCompleted) pending.complete({});
        return const Ok(null);
      });
      final batch = CbfBackgroundSync(
        routing: BitcoinSyncRouting(
          facade: facade,
          settings: settings,
          tor: () => throw StateError('unused'),
        ),
        wallets: () async => [],
        deadline: () => DateTime.now().toUtc().add(const Duration(seconds: 5)),
      );
      final result = batch.synchronize(
        const WalletNetworkKey('public', 'bitcoin', 'mainnet'),
      );
      await entered.future;
      final acknowledged = stopActiveCbfBackgroundSync();
      expect((await result as Err).failure, isA<WalletSyncDeferredFailure>());
      expect(await acknowledged, isTrue);
      verify(() => facade.setCbfForegroundActive(false)).called(1);
      verify(() => facade.stopCbfNodes()).called(2);
    },
  );
  test(
    'a worker starting after foreground activation cannot build a node',
    () async {
      final presence = CbfForegroundPresence();
      await presence.setActive(true);
      final facade = _Facade();
      try {
        final batch = CbfBackgroundSync(
          routing: BitcoinSyncRouting(
            facade: facade,
            settings: _Settings(),
            tor: () => throw StateError('unused'),
          ),
          wallets: () async => throw StateError('must not enumerate'),
          deadline: () =>
              DateTime.now().toUtc().add(const Duration(seconds: 5)),
        );
        expect(
          (await batch.synchronize(
                    const WalletNetworkKey('public', 'bitcoin', 'mainnet'),
                  )
                  as Err)
              .failure,
          isA<WalletSyncDeferredFailure>(),
        );
        verifyZeroInteractions(facade);
      } finally {
        await presence.dispose();
      }
    },
  );
  test(
    'foreground waits for the headless native termination acknowledgement',
    () async {
      final background = _Facade(),
          foreground = _Facade(),
          settings = _Settings(),
          metadata = _Metadata();
      final entered = Completer<void>();
      final stopped = Completer<Result<void, WalletTransactionSyncFailure>>();
      final pending = Completer<Map<WalletNetworkKey, CbfBackgroundOutcome>>();
      final wallets = StreamController<List<WalletMetadataModel>>();
      var foregroundStarts = 0;
      when(
        () => background.catchUpCbfWallets(
          any(),
          deadline: any(named: 'deadline'),
        ),
      ).thenAnswer((_) async {
        entered.complete();
        return pending.future;
      });
      when(() => background.stopCbfNodes()).thenAnswer((_) => stopped.future);
      when(
        () => foreground.stopCbfNodes(),
      ).thenAnswer((_) async => const Ok(null));
      when(() => foreground.reconcileCbfWallets(any())).thenAnswer((_) async {
        foregroundStarts++;
        return const Ok(null);
      });
      when(
        () => metadata.watchSyncPolicies(),
      ).thenAnswer((_) => wallets.stream);
      final batch = CbfBackgroundSync(
        routing: BitcoinSyncRouting(
          facade: background,
          settings: settings,
          tor: () => throw StateError('unused'),
        ),
        wallets: () async => [],
        deadline: () => DateTime.now().toUtc().add(const Duration(seconds: 5)),
      );
      final result = batch.synchronize(
        const WalletNetworkKey('public', 'bitcoin', 'mainnet'),
      );
      await entered.future;
      final lifecycle = CbfLifecycle(
        routing: BitcoinSyncRouting(
          facade: foreground,
          settings: settings,
          tor: () => throw StateError('unused'),
        ),
        metadata: metadata,
      )..start(AppLifecycleState.resumed);
      wallets.add([]);
      try {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(foregroundStarts, 0);
      } finally {
        stopped.complete(const Ok(null));
        pending.complete({});
        await result;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await lifecycle.dispose();
        await wallets.close();
      }
    },
  );
}
