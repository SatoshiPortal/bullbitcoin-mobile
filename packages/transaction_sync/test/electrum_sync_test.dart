import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Holds every pass at the connection until [release], then throws [thrown].
final class _ThrowingPort implements WalletConnectionPort {
  final Object thrown;
  final release = Completer<void>();
  int calls = 0;

  _ThrowingPort(this.thrown);

  @override
  Future<Result<T, TransactionSyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, TransactionSyncFailure>> Function(
      WalletConnection,
    )
    operation,
    required bool Function(TransactionSyncFailure) mayRetry,
  }) async {
    calls++;
    await release.future;
    throw thrown;
  }
}

void main() {
  final descriptor = BitcoinWalletDescriptor(
    key: WalletKey(id: 'wallet', network: BitcoinNetwork.testnet),
    scriptType: ScriptType.bip84,
    origin: 'wallet',
    externalDescriptor: 'wpkh(public)',
    internalDescriptor: 'wpkh(change)',
  );

  ElectrumSync engine(WalletConnectionPort port) => ElectrumSync(
    connections: port,
    documentsDirectory: () async => '/nonexistent',
    readRevision: (_) async => const Err(TransactionSyncNotFoundFailure()),
  );

  for (final (name, thrown) in [
    ('a programmer error', StateError('bug')),
    ('an object neither Exception nor Error', #sentinel),
  ]) {
    test('$name reaches every waiting caller', () async {
      final port = _ThrowingPort(thrown);
      final sync = engine(port);
      final finished = sync.finished.first;
      final first = sync.execute(descriptor);
      final joined = sync.execute(descriptor);
      port.release.complete();
      await expectLater(first, throwsA(same(thrown)));
      await expectLater(joined, throwsA(same(thrown)));
      expect((await finished).key, descriptor.key);
      expect(sync.isSyncing(), isFalse);
    });
  }

  test('a discovery queued behind a failed pass still runs', () async {
    final port = _ThrowingPort(StateError('bug'));
    final sync = engine(port);
    final routine = sync.execute(descriptor);
    final discovery = sync.execute(descriptor, discover: true);
    port.release.complete();
    await expectLater(routine, throwsA(isA<StateError>()));
    await expectLater(discovery, throwsA(isA<StateError>()));
    expect(port.calls, 2);
    expect(sync.isSyncing(), isFalse);
  });

  test('an unexpected exception settles as a storage failure', () async {
    final port = _ThrowingPort(const FormatException('detail'));
    final sync = engine(port);
    final pass = sync.execute(descriptor);
    port.release.complete();
    expect(
      (await pass as Err<SyncCompletion, TransactionSyncFailure>).failure,
      isA<TransactionSyncStorageFailure>(),
    );
    expect(sync.isSyncing(), isFalse);
  });
}
