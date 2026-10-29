import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:bb_mobile/core/background_tasks/cbf_background_sync.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/src/data/bdk/bdk_cbf_node.dart';
import 'package:transaction_sync/src/data/bdk/bdk_cbf_service.dart';
import 'package:transaction_sync/transaction_sync.dart';

const _account =
    '[73c5da0a/84h/0h/0h]xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V';
const _name = 'bull.cbf.foreground.active';
const _bound = BdkCbfConfiguration.nativeTerminationBoundAfterOwnerExit;

class _Metadata implements WalletCbfMetadataPort {
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
  ) async => false;
  @override
  Future<void> completeCbfDiscovery(
    WalletNetworkKey key,
    String policy,
  ) async {}
}

Future<void> _owner(List<Object> args) async {
  final ready = args[0] as SendPort;
  final port = args[1] as int;
  final presence = CbfForegroundPresence();
  if (!await presence.setActive(true) || !await presence.armNative()) {
    ready.send(false);
    return;
  }
  final service = BdkCbfService(
    metadata: _Metadata(),
    coordinator: InMemoryWalletSourceOperationCoordinator(),
    publish: (_, _, _, _) async => const Err(SourceStorageFailure()),
    nodeFactory: (wallets, _) {
      var builder = bdk.CbfBuilder();
      void replace(bdk.CbfBuilder next) {
        builder.dispose();
        builder = next;
      }

      final address = bdk.IpAddress.fromIpv4(q1: 127, q2: 0, q3: 0, q4: 1);
      try {
        replace(builder.connections(connections: 1));
        replace(
          builder.ownerLeaseMillis(
            ttlMillis: BdkCbfConfiguration.ownerLease.inMilliseconds,
          ),
        );
        replace(
          builder.configureTimeoutMillis(handshake: 60000, response: 60000),
        );
        replace(builder.onlyConfiguredPeers());
        replace(
          builder.peers(
            peers: [bdk.Peer(address: address, port: port, v2Transport: false)],
          ),
        );
        return NativeBdkCbfReactiveNode.fromComponents(
          builder.buildWithWallets(wallets: wallets),
        );
      } finally {
        address.dispose();
        builder.dispose();
      }
    },
  );
  service.nativeOwnerMonitor = presence.trackNativeNode;
  final started = await service.reconcile([
    WalletSourceRegistration.withFingerprint(
      key: const WalletNetworkKey('public', 'bitcoin', 'mainnet'),
      sourceKind: 'bdk_electrum',
      configuration: BdkCbfConfiguration(
        externalPublicDescriptor: 'wpkh($_account/0/*)',
        internalPublicDescriptor: 'wpkh($_account/1/*)',
        isTestnet: false,
        databaseFilePath: '${args[2]}/wallet.sqlite',
        checkpoint: BitcoinSyncCheckpoint.segwit,
        torRequired: false,
      ),
    ),
  ]);
  ready.send(started is Ok);
}

Set<String> _threads() {
  final result = <String>{};
  for (final task in Directory('/proc/self/task').listSync()) {
    try {
      if (File('${task.path}/comm').readAsStringSync().trim() == 'bdk-cbf') {
        result.add(task.path);
      }
    } on FileSystemException {
      /* Thread exited during enumeration. */
    }
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'app owner death expires native node before registry replacement',
    () async {
      final before = _threads();
      final directory = await Directory.systemTemp.createTemp(
        'cbf-owner-lease-',
      );
      final peer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final connected = Completer<void>();
      final sockets = <Socket>[];
      final listener = peer.listen((socket) {
        sockets.add(socket);
        socket.listen((_) {});
        if (!connected.isCompleted) connected.complete();
      });
      final ready = ReceivePort(), exited = ReceivePort();
      final replacement = CbfForegroundPresence();
      Isolate? owner;
      try {
        owner = await Isolate.spawn(_owner, <Object>[
          ready.sendPort,
          peer.port,
          directory.path,
        ], onExit: exited.sendPort);
        expect(await ready.first.timeout(const Duration(seconds: 10)), isTrue);
        await connected.future.timeout(const Duration(seconds: 5));
        expect(_threads().difference(before), hasLength(1));
        // Stay alive beyond a full lease to prove that the app renews it.
        await Future<void>.delayed(const Duration(seconds: 6));
        expect(_threads().difference(before), hasLength(1));
        final resume = owner.pause();
        await Future<void>.delayed(_bound);
        expect(
          _threads().difference(before),
          isEmpty,
          reason: 'a frozen engine must let the native lease expire',
        );
        final oldConnections = sockets.length;
        owner.resume(resume);
        for (var i = 0; i < 200 && sockets.length == oldConnections; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        expect(
          sockets.length,
          oldConnections + 1,
          reason: 'resume must rebuild the expired service node',
        );
        expect(_threads().difference(before), hasLength(1));
        print('frozen owner expired and rebuilt cleanly on resume');
        owner.kill(priority: Isolate.immediate);
        await exited.first;
        expect(await replacement.setActive(true), isFalse);
        final elapsed = Stopwatch()..start();
        await Future<void>.delayed(_bound);
        print('post-bound native threads: ${_threads().difference(before)}');
        expect(
          _threads().difference(before),
          isEmpty,
          reason:
              'the app node must terminate within TTL + margin after owner exit',
        );
        for (
          var i = 0;
          i < 40 && IsolateNameServer.lookupPortByName(_name) != null;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        expect(await replacement.setActive(true), isTrue);
        print(
          'native thread gone and replacement admitted after ${elapsed.elapsedMilliseconds} ms; process survived',
        );
      } finally {
        owner?.kill(priority: Isolate.immediate);
        ready.close();
        exited.close();
        await replacement.dispose();
        for (final socket in sockets) {
          socket.destroy();
        }
        await listener.cancel();
        await peer.close();
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isLinux,
  );
}
