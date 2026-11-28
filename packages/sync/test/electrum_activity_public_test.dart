import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';
import 'package:test/test.dart';

final class _BlockedConnection implements WalletConnectionPort {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    entered.complete();
    await release.future;
    return const Err(SyncConnectionFailure());
  }
}

void main() {
  test(
    'aggregate activity and individual wallet activity are distinct',
    () async {
      final connection = _BlockedConnection();
      final sync = ElectrumSync(
        connections: connection,
        documentsDirectory: () async => '/nonexistent',
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      );
      final descriptor = BitcoinWalletDescriptor(
        key: WalletKey(id: 'w1', network: BitcoinNetwork.mainnet),
        scriptType: ScriptType.bip84,
        origin: 'test',
        externalDescriptor: 'wpkh(public)',
        internalDescriptor: 'wpkh(change)',
      );
      final result = sync.execute(descriptor);
      await connection.entered.future;
      expect(sync.isSyncing(walletId: 'w1'), isTrue);
      expect(sync.isSyncing(walletId: 'w2'), isFalse);
      expect(sync.isSyncing(), isTrue);
      connection.release.complete();
      expect(await result, isA<Err<SyncCompletion, SyncFailure>>());
      expect(sync.isSyncing(walletId: 'w1'), isFalse);
      expect(sync.isSyncing(), isFalse);
    },
  );
}
