import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:silent/silent.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:sync/sync.dart';

class _Inventory extends Mock implements WalletInventory {}

class _Settings extends Mock implements ActiveEnvironmentReader {}

class _Swaps extends Mock implements SwapActivity {}

class _Sp extends Mock implements Silent {}

final class _Catalog implements WalletCatalogPort {
  _Catalog(this.descriptors);

  final Map<String, PublicWalletDescriptor> descriptors;

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(WalletKey key) async {
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
  late OverviewSynchronization foreground;
  late List<String> synced;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final settings = _Settings();
    when(settings.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.mainnet));
    inventory = _Inventory();
    synced = [];
    foreground = OverviewSynchronization.open(
      inventory: inventory,
      environment: settings,
      catalog: () => _Catalog({
        for (final id in ['btc-1', 'btc-2']) id: _descriptor(id),
      }),
      synchronize: (
        descriptor, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async {
        synced.add(descriptor.key.id);
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

    expect(synced, ['btc-1', 'btc-2']);
  });

  test('an incompletely read selection syncs its readable wallets and fails', () async {
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
    expect(synced, ['btc-1']);
  });

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
    expect(synced, ['btc-1', 'btc-1']);
  });

  test('an unreadable selection fails as a storage read, never as empty', () async {
    stubBitcoin(const Err(UnreadableWalletFailure()));

    final failure = await failureOf(
      foreground.coordinator.sync(only: {SyncKind.bitcoin}),
    );

    expect(failure, isA<SyncStorageFailure>());
    expect(synced, isEmpty);
  });

  test('a complete, empty selection reports no wallets', () async {
    stubBitcoin(Ok(walletSelectionForTesting([])));

    final failure = await failureOf(
      foreground.coordinator.sync(only: {SyncKind.bitcoin}),
    );

    expect(failure, isA<SyncNotFoundFailure>());
    expect(synced, isEmpty);
  });
}
