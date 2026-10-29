import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/src/data/bdk/bdk_cbf_node.dart';
import 'package:transaction_sync/src/data/bdk/bdk_wallet_transaction_source.dart';
import 'package:transaction_sync/transaction_sync.dart';

final class _Update implements BdkCbfUpdate {
  @override
  void apply(bdk.Wallet wallet) {
    final hash = bdk.BlockHash.fromString(hex: '1'.padLeft(64, '0'));
    try {
      wallet.insertCheckpoint(blockId: bdk.BlockId(height: 500000, hash: hash));
    } finally {
      hash.dispose();
    }
  }

  @override
  void dispose() {}
}

final class _Node extends Fake implements BdkCbfReactiveNode {
  final update = Completer<Map<String, BdkCbfUpdate>>();
  final stopped = Completer<void>();
  final networkFailure = Completer<void>();
  Map<String, BdkCbfUpdate>? batch;
  _Node() {
    update.future.then((value) => batch = value);
  }
  @override
  void run() {}
  @override
  Future<SendPort?> prepare() async => null;
  @override
  void renewLease() {}
  @override
  BdkCbfBatch? pollUpdateBatch() {
    if (networkFailure.isCompleted) throw const FormatException('network');
    final value = batch;
    batch = null;
    return value == null
        ? null
        : BdkCbfBatch(updates: value, scannedHeight: 500000, syncedToTip: true);
  }

  @override
  List<bdk.Info> drainInfo() => [];
  @override
  void drainWarnings() {}
  @override
  bool get isTerminated => stopped.isCompleted;
  @override
  bdk.CbfStatus status() => bdk.CbfStatus(
    running: !isTerminated,
    terminated: isTerminated,
    infoDropped: 0,
    warningsDropped: 0,
  );

  @override
  void shutdown() {
    if (!stopped.isCompleted) stopped.complete();
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reactive deletion refuses ordinary sync and explicit discovery revives the source',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cbf-facade-delete',
      );
      final fixture =
          File('test/fixtures/cbf_public_descriptors.json').existsSync()
          ? File('test/fixtures/cbf_public_descriptors.json')
          : File(
              'packages/transaction_sync/test/fixtures/cbf_public_descriptors.json',
            );
      final descriptors =
          jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
      final metadata = await SqliteWalletSyncMetadataStore.open(
        databasePath: '${directory.path}/metadata.sqlite',
      );
      final nodes = <_Node>[];
      final ids = <String>[];
      final facade = WalletTransactionSyncFacade(
        source: BdkWalletTransactionSource(
          cbfNodeFactory: (wallets, config) {
            ids.add(
              wallets.single.descriptorId(keychain: bdk.KeychainKind.external_),
            );
            final node = _Node();
            nodes.add(node);
            return node;
          },
        ),
        metadata: metadata,
        coordinator: InMemoryWalletSourceOperationCoordinator(),
      );
      addTearDown(() async {
        await facade.dispose();
        await metadata.close();
        await directory.delete(recursive: true);
      });
      final registration = WalletSourceRegistration.withFingerprint(
        key: const WalletNetworkKey('public', 'bitcoin', 'mainnet'),
        sourceKind: 'bdk_electrum',
        configuration: BdkCbfConfiguration(
          externalPublicDescriptor: descriptors['external'] as String,
          internalPublicDescriptor: descriptors['internal'] as String,
          isTestnet: false,
          databaseFilePath: '${directory.path}/wallet.sqlite',
          checkpoint: BitcoinSyncCheckpoint.segwit,
        ),
      );
      Future<void> emit(int count) async {
        for (var i = 0; i < 300 && nodes.length < count; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(nodes, hasLength(count));
        nodes.last.update.complete({ids.last: _Update()});
      }

      final first = facade.discoverWalletHistory(
        DiscoverWalletHistoryRequest(registration),
      );
      await emit(1);
      expect(
        await first,
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
      final cached = await facade.discoverWalletHistory(
        DiscoverWalletHistoryRequest(registration),
      );
      expect(
        cached,
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
      expect(
        await facade.watchWalletState(registration.key).first,
        isA<WalletStateReady>(),
      );
      final failed = facade
          .watchWalletState(registration.key)
          .firstWhere((state) => state is WalletStateFailed);
      nodes.single.networkFailure.complete();
      final failureState = await failed.timeout(
        const Duration(milliseconds: 300),
      );
      expect(
        (failureState as WalletStateFailed).failure,
        isA<CbfNoPeersFailure>(),
      );
      expect(
        await facade.deleteWallet(registration.key),
        isA<Ok<void, WalletTransactionSyncFailure>>(),
      );
      expect(File('${directory.path}/wallet.sqlite').existsSync(), isFalse);
      final refused = await facade.synchronizeWallet(
        SynchronizeWalletRequest(registration),
      );
      expect((refused as Err).failure, isA<DeletedWalletFailure>());
      expect(nodes, hasLength(1));
      final second = facade.discoverWalletHistory(
        DiscoverWalletHistoryRequest(registration),
      );
      await emit(2);
      expect(
        await second,
        isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
      );
    },
  );
}
