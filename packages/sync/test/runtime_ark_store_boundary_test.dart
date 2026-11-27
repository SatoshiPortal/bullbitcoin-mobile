import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/src/data/write/writer_lock.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore, NoConnections;
import 'package:sync/write.dart';

import 'support/regtest_wallet.dart';

void main() {
  late Directory directory;
  late BitcoinWalletDescriptor descriptor;
  late WalletRevision revision;
  late _Reservations ordinary;
  late _Reservations funding;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('sync-ark-boundary-');
    addTearDown(() => directory.deleteSync(recursive: true));
    descriptor = regtestDescriptor();
    final store = RevisionStoreDatasource.openForeground(
      revisionStorePath(directory.path),
    );
    try {
      store.begin(descriptor.key, WriteIntent.create);
      store.finish(descriptor.key, initializedDescriptor: descriptor);
      store.begin(descriptor.key, WriteIntent.sync);
      revision = store.finish(descriptor.key).stamp;
    } finally {
      store.close();
    }
    ordinary = _Reservations();
    funding = _Reservations();
  });

  WalletNativeRuntime runtime({
    Future<String> Function()? path,
    FreezeStorePort? freezes,
  }) {
    const connections = NoConnections();
    final result = WalletNativeRuntime.open(
      catalog: SingleWalletCatalog(descriptor),
      reserved: NoReservedAddresses(),
      inputReservations: ordinary,
      fundingReservations: funding,
      deleteCatalogEntry: (_) async => throw StateError('Unexpected deletion'),
      sync: ElectrumSync(
        connections: connections,
        documentsDirectory: () async => throw StateError('Unexpected sync'),
        readRevision: (_) async => throw StateError('Unexpected sync'),
      ),
      documentsDirectory: path ?? () async => directory.path,
      freezes: freezes ?? MemoryFreezeStore(),
      connections: connections,
    );
    addTearDown(() async => expect(await result.close(), isA<Ok>()));
    return result;
  }

  test('close drains a freeze read admitted before opening', () async {
    final opening = Completer<void>();
    final directoryPath = Completer<String>();
    final readingStore = Completer<void>();
    final finishRead = Completer<void>();
    final journal = <String>[];
    const input = (txId: 'fixture', vout: 1);
    var reads = 0;
    final freezes = _FreezeReads(() async {
      // The first read is the lazy Sync mount warming its freeze policy.
      if (++reads == 1) return const Ok([]);
      journal.add('read');
      readingStore.complete();
      await finishRead.future;
      journal.add('settled');
      return const Ok([
        FrozenOutpoint(input, origin: 'another wallet'),
        FrozenOutpoint(input, origin: 'second attribution'),
      ]);
    });
    final sync = runtime(
      freezes: freezes,
      path: () {
        opening.complete();
        return directoryPath.future;
      },
    );
    addTearDown(() {
      if (!directoryPath.isCompleted) directoryPath.complete(directory.path);
      if (!finishRead.isCompleted) finishRead.complete();
    });
    final read = sync.readFrozenOutpoints();
    await opening.future;
    final closing = sync.close();
    expect(sync.close(), same(closing));
    final closed = closing.then((result) {
      expect(result, isA<Ok>());
      journal.add('closed');
    });
    expectClosed(await sync.readFrozenOutpoints());
    expect(reads, 0);
    directoryPath.complete(directory.path);
    await readingStore.future;
    expect(journal, ['read']);
    finishRead.complete();
    expect(
      await read,
      isA<Ok<Set<Outpoint>, SyncFailure>>().having(
        (result) => result.value,
        'outpoints without origin',
        {input},
      ),
    );
    await closed;
    expect(journal, ['read', 'settled', 'closed']);
    expectClosed(await sync.readFrozenOutpoints());
    expect(reads, 2);
  });

  for (final error in <Object?>[
    null,
    Exception('callback'),
    StateError('bug'),
  ]) {
    test(
      'owns the writer lease through callback settlement ($error)',
      () async {
        final sync = runtime();
        final journal = <String>[];
        final entered = Completer<WalletRevision>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        final effect = sync.withBitcoinRevisionAdmission(descriptor.key, (
          actual,
        ) async {
          journal.add('callback');
          entered.complete(actual);
          await release.future;
          journal.add('callback settled');
          if (error != null) throw error;
        });
        final outcome = error == null
            ? effect.then((result) => expect(result, isA<Ok>()))
            : expectLater(effect, throwsA(same(error)));
        expect(await entered.future, revision);
        expect(
          await _probe(directory.path, descriptor.key),
          isA<SyncBusyFailure>(),
        );

        final closing = sync.close();
        expect(sync.close(), same(closing));
        final closed = closing.then((result) {
          journal.add('closed');
          expect(result, isA<Ok>());
        });
        expectClosed(await sync.readReservedOutpointsForDisplay());
        expectClosed(
          await sync.withBitcoinRevisionAdmission(
            descriptor.key,
            (_) async => fail('A late callback was admitted'),
          ),
        );
        expect(journal, ['callback']);
        release.complete();
        await outcome;
        await closed;
        expect(journal, ['callback', 'callback settled', 'closed']);
        // The caller can now use the wallet outside the admission (e.g. sign).
        expect(await _probe(directory.path, descriptor.key), isNull);
      },
    );
  }

  test('a normal refusal is busy and does not invoke the callback', () async {
    final sync = runtime();
    final missing = WalletKey(
      id: 'not-registered:regtest',
      network: BitcoinNetwork.regtest,
    );
    final result = await sync.withBitcoinRevisionAdmission(
      missing,
      (_) async => fail('Refusal invoked the callback'),
    );
    expect(
      result,
      isA<Err>().having(
        (err) => err.failure,
        'failure',
        isA<SyncBusyFailure>(),
      ),
    );
    expect(await _probe(directory.path, missing), isNull);
  });

  test(
    'a reservation read already admitted before opening delays close',
    () async {
      final entering = Completer<void>();
      final path = Completer<String>();
      final provider = Completer<void>();
      final release = Completer<Result<List<InputReservation>, SyncFailure>>();
      final journal = <String>[];
      ordinary.read = () async {
        journal.add('ordinary');
        provider.complete();
        return release.future;
      };
      funding.read = () async {
        journal.add('funding');
        return const Ok([]);
      };
      final sync = runtime(
        path: () {
          entering.complete();
          return path.future;
        },
      );
      addTearDown(() {
        if (!path.isCompleted) path.complete(directory.path);
        if (!release.isCompleted) release.complete(const Ok([]));
      });
      final reading = sync.readReservedOutpointsForDisplay();
      await entering.future;
      final closing = sync.close();
      final closed = closing.then((result) {
        journal.add('closed');
        expect(result, isA<Ok>());
      });
      expectClosed(await sync.readReservedOutpointsForDisplay());
      path.complete(directory.path);
      await provider.future;
      expect(journal, ['ordinary']);
      release.complete(const Ok([]));
      expect(
        await reading,
        isA<Ok>().having((ok) => ok.value, 'known empty', isEmpty),
      );
      await closed;
      expect(journal, ['ordinary', 'funding', 'closed']);
    },
  );

  test(
    'the snapshot combines and deduplicates, but a typed failure is unknown',
    () async {
      const first = (txId: 'ordinary', vout: 0);
      const second = (txId: 'funding', vout: 1);
      InputReservation held(Outpoint point) => InputReservation(
        outpoint: point,
        protocol: 'fixture',
        session: 'source',
        walletId: descriptor.key.id,
        network: BitcoinNetwork.regtest,
        state: 'pending',
      );
      ordinary.read = () async => Ok([held(first)]);
      funding.read = () async => Ok([held(first), held(second)]);
      final sync = runtime();
      final result = await sync.readReservedOutpointsForDisplay();
      expect(
        result,
        isA<Ok>().having((ok) => ok.value, 'outpoints', {first, second}),
      );
      funding.read = () async => const Err(SyncStorageFailure());
      expect(
        await sync.readReservedOutpointsForDisplay(),
        isA<Ok>().having((ok) => ok.value, 'unknown', isNull),
      );
    },
  );
}

void expectClosed<T>(Result<T, SyncFailure> result) => expect(
  result,
  isA<Err<T, SyncFailure>>().having(
    (err) => err.failure,
    'failure',
    isA<SyncClosedFailure>(),
  ),
);

Future<SyncFailure?> _probe(String path, WalletKey key) => Isolate.run(() {
  return switch (WriterLock.acquire(path, key)) {
    Err(:final failure) => failure,
    Ok(:final value) => () {
      value.release();
      return null;
    }(),
  };
});

final class _Reservations implements FundingReservationPort {
  Future<Result<List<InputReservation>, SyncFailure>> Function() read =
      () async => const Ok([]);

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() => read();

  @override
  Future<Result<void, SyncFailure>> reserve({
    required WalletKey key,
    required UnsignedSpend spend,
    required String context,
  }) => throw StateError('Unexpected reserve');
}

final class _FreezeReads implements FreezeStorePort {
  final Future<Result<List<FrozenOutpoint>, SyncFailure>> Function() _read;

  _FreezeReads(this._read);

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll() => _read();

  @override
  Future<Result<void, SyncFailure>> freeze(List<FrozenOutpoint> rows) =>
      throw StateError('Unexpected freeze');

  @override
  Future<Result<void, SyncFailure>> unfreeze(List<Outpoint> outpoints) =>
      throw StateError('Unexpected unfreeze');
}
