import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart'
    show multiViewSupported, SecretsInventory, ViewId;
import 'package:secrets/testing.dart';
import 'package:silent/silent.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:sync/sync.dart';

import '../../../support/inventory_fixture.dart';

class _Inventory extends Mock implements WalletInventory {}

class _Settings extends Mock implements ActiveEnvironmentReader {}

class _Swaps extends Mock implements SwapActivity {}

class _Sp extends Mock implements Silent {}

final class _Catalog implements WalletCatalogPort {
  _Catalog(this.descriptors);

  final Map<String, PublicWalletDescriptor> descriptors;

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async {
    final descriptor = descriptors[key.id];
    return descriptor == null
        ? const Err(SyncNotFoundFailure())
        : Ok(descriptor);
  }

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      Ok(descriptors.values.toList());
}

PublicWalletDescriptor _descriptor(String id) => BitcoinWalletDescriptor(
  key: WalletKey(id: id, network: BitcoinNetwork.mainnet),
  scriptType: ScriptType.bip84,
  origin: 'test',
  externalDescriptor: 'wpkh(public)',
  internalDescriptor: 'wpkh(change)',
);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late _Inventory inventory;
  SecretsInventory? sessionInventory;
  late OverviewSynchronization foreground;
  late List<PublicWalletDescriptor> synced;
  late Map<String, PublicWalletDescriptor> descriptors;

  List<String> syncedIds() => [for (final wallet in synced) wallet.key.id];

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final settings = _Settings();
    when(settings.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.mainnet));
    inventory = _Inventory();
    sessionInventory = null;
    synced = [];
    descriptors = {
      for (final id in ['btc-1', 'btc-2']) id: _descriptor(id),
    };
    foreground = OverviewSynchronization.open(
      inventory: inventory,
      readInSession: <T>(Future<T> Function() read) async {
        final live = sessionInventory;
        if (live != null) return live.readInSession(read);
        return Ok(await read());
      },
      environment: settings,
      catalog: () => _Catalog(descriptors),
      synchronize:
          (
            descriptor, {
            discover = false,
            allowInitialScan = true,
            reason = SyncReason.auto,
          }) async {
            synced.add(descriptor);
            return const Ok(null);
          },
      refreshRevisions: () async => const Ok(null),
      swaps: () => _Swaps(),
      silent: () => _Sp(),
    );
  });

  tearDown(() => foreground.close());

  void stubBitcoin(Result<WalletSelection, SecretFailure> selection) {
    when(() => inventory.walletsForNetwork(BitcoinNetwork.mainnet))
        .thenAnswer((_) async => selection);
  }

  Future<Object?> failureOf(Future<void> call) async {
    try {
      await call;
      return null;
    } on SyncCoordinatorException catch (e) {
      return e.failures[SyncKind.bitcoin];
    }
  }

  test('a complete selection syncs every wallet and settles', () async {
    stubBitcoin(
      Ok(
        walletSelectionForTesting([
          walletRegistrationForTesting(
            id: 'btc-1',
            network: BitcoinNetwork.mainnet,
          ),
          walletRegistrationForTesting(
            id: 'btc-2',
            network: BitcoinNetwork.mainnet,
          ),
        ]),
      ),
    );

    await foreground.coordinator.sync(only: {SyncKind.bitcoin});

    expect(syncedIds(), ['btc-1', 'btc-2']);
  });

  test(
    'an incompletely read selection syncs its readable wallets and fails',
    () async {
      stubBitcoin(
        Ok(
          walletSelectionForTesting([
            walletRegistrationForTesting(
              id: 'btc-1',
              network: BitcoinNetwork.mainnet,
            ),
          ], isComplete: false),
        ),
      );

      final failure = await failureOf(
        foreground.coordinator.sync(only: {SyncKind.bitcoin}),
      );

      expect(failure, isA<SyncStorageFailure>());
      // The readable wallet is still synced: only the pass fails.
      expect(syncedIds(), ['btc-1']);
    },
  );

  test('a failed incomplete pass is not throttled', () async {
    stubBitcoin(
      Ok(
        walletSelectionForTesting([
          walletRegistrationForTesting(
            id: 'btc-1',
            network: BitcoinNetwork.mainnet,
          ),
        ], isComplete: false),
      ),
    );

    await failureOf(foreground.coordinator.sync(only: {SyncKind.bitcoin}));
    await failureOf(foreground.coordinator.sync(only: {SyncKind.bitcoin}));

    // A successful pass would have stamped the throttle window and dropped the
    // second automatic pass, hiding the unreadable rows until a user pull.
    expect(syncedIds(), ['btc-1', 'btc-1']);
  });

  test(
    'an unreadable selection fails as a storage read, never as empty',
    () async {
      stubBitcoin(const Err(UnreadableWalletFailure()));

      final failure = await failureOf(
        foreground.coordinator.sync(only: {SyncKind.bitcoin}),
      );

      expect(failure, isA<SyncStorageFailure>());
      expect(synced, isEmpty);
    },
  );

  test('a complete, empty selection reports no wallets', () async {
    stubBitcoin(Ok(walletSelectionForTesting([])));

    final failure = await failureOf(
      foreground.coordinator.sync(only: {SyncKind.bitcoin}),
    );

    expect(failure, isA<SyncNotFoundFailure>());
    expect(synced, isEmpty);
  });

  test('a queued discovery fails if selection crosses A to B to A', () async {
    FakeSecureStoragePlatform().install();
    final directory = await Directory.systemTemp.createTemp('overview-view-');
    addTearDown(() => directory.delete(recursive: true));
    final fixture = await InventoryFixture.open(directory);
    addTearDown(fixture.close);
    final live = fixture.inventory;
    sessionInventory = live;
    final views = live.openedViews ?? fail('Expected an open inventory');
    const firstView = ViewId('all');
    final other = await views.administration.create(name: 'Other');
    final otherId = switch (other) {
      Ok(:final value) => value.id,
      Err(:final failure) => fail('Creating second view failed: $failure'),
    };
    const id = 'wpkh([01234567/84h/0h/0h])';
    await fixture.addPublicWallet(id: id, network: 'bitcoinMainnet');
    descriptors[id] = _descriptor(id);

    final reachedLiquid = Completer<void>();
    final resumeLiquid = Completer<void>();
    var bitcoinReads = 0;
    var liquidReads = 0;
    when(() => inventory.walletsForNetwork(BitcoinNetwork.mainnet))
        .thenAnswer((_) {
          bitcoinReads++;
          return live.walletsForNetwork(BitcoinNetwork.mainnet);
        });
    when(() => inventory.walletsForNetwork(LiquidNetwork.mainnet))
        .thenAnswer((_) async {
          if (++liquidReads == 2) {
            reachedLiquid.complete();
            await resumeLiquid.future;
          }
          return live.walletsForNetwork(LiquidNetwork.mainnet);
        });

    final discovery = foreground.coordinator.discoverWallet(id);
    await reachedLiquid.future;
    try {
      expect(bitcoinReads, 2);
      expect(await views.activate(otherId), isA<Ok>());
      expect(await live.readWallet(id), isA<Err>());
      expect(await views.activate(firstView), isA<Ok>());
      expect(await live.readWallet(id), isA<Ok>());
    } finally {
      resumeLiquid.complete();
    }

    expect(
      await discovery,
      isA<Err<void, WalletDiscoveryFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletDiscoveryUnavailableFailure>(),
      ),
    );
    expect(synced, isEmpty);

    expect(await foreground.coordinator.discoverWallet(id), isA<Ok>());
    expect(syncedIds(), [id]);
  }, skip: multiViewSupported ? false : 'Requires BULL_MULTI_VIEW=true');

  test('the queued pass resolves the descriptor when it starts', () async {
    const id = 'btc-1';
    stubBitcoin(
      Ok(
        walletSelectionForTesting([
          walletRegistrationForTesting(id: id, network: BitcoinNetwork.mainnet),
        ]),
      ),
    );
    final original = descriptors[id];
    final replacement = _descriptor(id);
    var liquidReads = 0;
    when(() => inventory.walletsForNetwork(LiquidNetwork.mainnet))
        .thenAnswer((_) async {
          if (++liquidReads == 2) descriptors[id] = replacement;
          return Ok(walletSelectionForTesting([]));
        });

    expect(await foreground.coordinator.discoverWallet(id), isA<Ok>());
    expect(liquidReads, 2);
    expect(replacement, isNot(same(original)));
    expect(synced.single, same(replacement));
  });
}
