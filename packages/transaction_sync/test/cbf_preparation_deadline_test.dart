import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/src/data/bdk/bdk_cbf_service.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _WarmMetadata implements WalletCbfMetadataPort {
  final relayStates = <WalletNetworkKey, Map<String, CbfRelayState>>{};
  @override
  Future<Map<String, CbfRelayState>> readCbfRelayStates(
    WalletNetworkKey key,
  ) async => Map.of(relayStates[key] ?? {});
  @override
  Future<void> stageCbfTransaction(WalletNetworkKey key, String txid) async {
    relayStates
        .putIfAbsent(key, () => {})
        .putIfAbsent(txid, () => CbfRelayState.notBroadcast);
  }

  @override
  Future<void> writeCbfRelayState(
    WalletNetworkKey key,
    String txid,
    CbfRelayState state,
  ) async {
    final states = relayStates.putIfAbsent(key, () => {});
    if (states[txid] != CbfRelayState.relayed) states[txid] = state;
  }

  @override
  Future<bool> isCbfDiscoveryComplete(
    WalletNetworkKey key,
    String policy,
  ) async => true;
  @override
  Future<void> completeCbfDiscovery(
    WalletNetworkKey key,
    String policy,
  ) async {}
}

class _ContendedCoordinator implements WalletSourceOperationCoordinator {
  final inner = InMemoryWalletSourceOperationCoordinator();
  final entered = Completer<void>();
  final release = Completer<void>();
  Future<void>? holder;
  var calls = 0;
  @override
  Future<T> runExclusive<T>(
    WalletSourceKey key,
    Future<T> Function(WalletSourceSession) operation, {
    Duration? timeout = const Duration(seconds: 30),
    DateTime? admissionDeadline,
    bool allowRetired = false,
    WalletOperationKind kind = WalletOperationKind.refresh,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  }) async {
    calls++;
    // Eligibility succeeds; contend precisely when native-start preparation
    // requests its second source admission.
    if (calls == 2) {
      holder = inner.runExclusive(key, (_) async {
        entered.complete();
        await release.future;
      }, timeout: null);
      await entered.future;
    }
    return inner.runExclusive(
      key,
      operation,
      timeout: timeout,
      admissionDeadline: admissionDeadline,
      allowRetired: allowRetired,
      kind: kind,
      priority: priority,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('expired CBF preparation drains before cleanup reserve ends', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cbf-review-budget-',
    );
    final fixture = File('test/fixtures/cbf_public_descriptors.json');
    final descriptors =
        jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
    final path = '${directory.path}/wallet.sqlite';
    final external = bdk.Descriptor(
      descriptor: descriptors['external'] as String,
      networkKind: bdk.NetworkKind.main,
    );
    final internal = bdk.Descriptor(
      descriptor: descriptors['internal'] as String,
      networkKind: bdk.NetworkKind.main,
    );
    final persister = bdk.Persister.newSqlite(path: path);
    final wallet = bdk.Wallet(
      descriptor: external,
      changeDescriptor: internal,
      network: bdk.Network.bitcoin,
      persister: persister,
      lookahead: 1000,
    );
    final hash = bdk.BlockHash.fromString(
      hex: BitcoinSyncCheckpoint.segwit.blockHash,
    );
    wallet.insertCheckpoint(
      blockId: bdk.BlockId(
        height: BitcoinSyncCheckpoint.segwit.height,
        hash: hash,
      ),
    );
    wallet.persist(persister: persister);
    hash.dispose();
    wallet.dispose();
    persister.dispose();
    external.dispose();
    internal.dispose();
    final coordinator = _ContendedCoordinator();
    final service = BdkCbfService(
      metadata: _WarmMetadata(),
      coordinator: coordinator,
      nodeFactory: (_, _) =>
          throw StateError('Expired request must not create a native node'),
      publish: (_, _, _, _) async => const Err(WalletSyncDeferredFailure()),
    );
    final registration = WalletSourceRegistration.withFingerprint(
      key: const WalletNetworkKey('public', 'bitcoin', 'mainnet'),
      sourceKind: 'bdk_electrum',
      configuration: BdkCbfConfiguration(
        externalPublicDescriptor: descriptors['external'] as String,
        internalPublicDescriptor: descriptors['internal'] as String,
        isTestnet: false,
        databaseFilePath: path,
        checkpoint: BitcoinSyncCheckpoint.segwit,
      ),
    );
    Future<void>? disposal;
    try {
      final pending = service.catchUp([
        registration,
      ], DateTime.now().toUtc().add(const Duration(milliseconds: 200)));
      await coordinator.entered.future.timeout(const Duration(seconds: 5));
      final result = await pending;
      expect(
        (result[registration.key] as Err).failure,
        isA<WalletSyncDeferredFailure>(),
      );
      var disposed = false;
      disposal = service.dispose().then((_) => disposed = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        disposed,
        isTrue,
        reason:
            'expired preparation must drain without releasing the competing wallet',
      );
      coordinator.release.complete();
      await disposal.timeout(const Duration(seconds: 5));
      expect(disposed, isTrue);
    } finally {
      if (!coordinator.release.isCompleted) coordinator.release.complete();
      await coordinator.holder;
      await (disposal ?? service.dispose());
      await directory.delete(recursive: true);
    }
  });
}
