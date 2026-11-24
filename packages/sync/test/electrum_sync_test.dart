import 'dart:async';
import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

/// Holds every pass at the connection until [release], then throws [thrown].
final class _ThrowingPort implements WalletConnectionPort {
  final Object thrown;
  final release = Completer<void>();
  int calls = 0;

  _ThrowingPort(this.thrown);

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
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
  SyncTransactionTarget target(String txid) => SyncTransactionTarget(
    txid: txid,
    outputScripts: [
      Uint8List.fromList([0, 20, ...List.filled(20, 0x11)]),
    ],
  );

  ElectrumSync engine(WalletConnectionPort port) => ElectrumSync(
    connections: port,
    documentsDirectory: () async => '/nonexistent',
    readRevision: (_) async => const Err(SyncNotFoundFailure()),
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

  group('queueing', () {
    test('a routine refresh joins the routine pass already running', () async {
      final port = _ThrowingPort(StateError('bug'));
      final sync = engine(port);
      final first = sync.execute(descriptor);
      final joined = sync.execute(descriptor);
      port.release.complete();
      await expectLater(first, throwsA(isA<StateError>()));
      await expectLater(joined, throwsA(isA<StateError>()));
      expect(port.calls, 1);
    });

    test('targeted requests issued before the pass starts merge into one '
        'pass', () async {
      final port = _ThrowingPort(StateError('bug'));
      final sync = engine(port);
      final first = sync.execute(descriptor, targets: [target('a' * 64)]);
      final second = sync.execute(descriptor, targets: [target('b' * 64)]);
      port.release.complete();
      await expectLater(first, throwsA(isA<StateError>()));
      await expectLater(second, throwsA(isA<StateError>()));
      expect(
        port.calls,
        1,
        reason: 'a pass that has not started still covers both targets',
      );
    });

    test('a targeted request never joins a pass already running', () async {
      final port = _ThrowingPort(StateError('bug'));
      final sync = engine(port);
      final routine = sync.execute(descriptor);
      await sync.started.first;
      final targeted = sync.execute(descriptor, targets: [target('a' * 64)]);
      port.release.complete();
      await expectLater(routine, throwsA(isA<StateError>()));
      await expectLater(targeted, throwsA(isA<StateError>()));
      expect(
        port.calls,
        2,
        reason: 'a pass that began before the target existed proves nothing',
      );
    });

    test(
      'a targeted request started earlier does not absorb a later one',
      () async {
        final port = _ThrowingPort(StateError('bug'));
        final sync = engine(port);
        final first = sync.execute(descriptor, targets: [target('a' * 64)]);
        await sync.started.first;
        final second = sync.execute(descriptor, targets: [target('b' * 64)]);
        port.release.complete();
        await expectLater(first, throwsA(isA<StateError>()));
        await expectLater(second, throwsA(isA<StateError>()));
        expect(port.calls, 2);
      },
    );

    test('a routine refresh is never satisfied by a targeted pass', () async {
      final port = _ThrowingPort(StateError('bug'));
      final sync = engine(port);
      final targeted = sync.execute(descriptor, targets: [target('a' * 64)]);
      final routine = sync.execute(descriptor);
      port.release.complete();
      await expectLater(targeted, throwsA(isA<StateError>()));
      await expectLater(routine, throwsA(isA<StateError>()));
      expect(
        port.calls,
        2,
        reason: 'a targeted pass covers a few scripts, not the whole wallet',
      );
    });

    test('a targeted pass clears the wallet once it ends', () async {
      final port = _ThrowingPort(StateError('bug'));
      final sync = engine(port);
      final pass = sync.execute(descriptor, targets: [target('a' * 64)]);
      expect(sync.isSyncing(walletId: 'wallet'), isTrue);
      port.release.complete();
      await expectLater(pass, throwsA(isA<StateError>()));
      expect(sync.isSyncing(walletId: 'wallet'), isFalse);
    });
  });

  test(
    'a wallet without a targeted pass rejects targets before any work',
    () async {
      final port = _ThrowingPort(StateError('bug'));
      final sync = engine(port);
      final liquid = LiquidWalletDescriptor(
        key: WalletKey(id: 'liquid', network: LiquidNetwork.testnet),
        scriptType: ScriptType.bip84,
        origin: 'wallet',
        combinedCtDescriptor: 'ct(elwpkh(public))',
      );
      final result = await sync.execute(liquid, targets: [target('a' * 64)]);
      expect(
        (result as Err<SyncCompletion, SyncFailure>).failure,
        isA<SyncUnsupportedNetworkFailure>(),
        reason:
            'a Liquid wallet must never satisfy a targeted pass with a '
            'routine Liquid sync',
      );
      expect(port.calls, 0, reason: 'nothing reaches the connection port');
      expect(sync.isSyncing(), isFalse);
    },
  );

  test('an unexpected exception settles as a storage failure', () async {
    final port = _ThrowingPort(const FormatException('detail'));
    final sync = engine(port);
    final pass = sync.execute(descriptor);
    port.release.complete();
    expect(
      (await pass as Err<SyncCompletion, SyncFailure>).failure,
      isA<SyncStorageFailure>(),
    );
    expect(sync.isSyncing(), isFalse);
  });
}
