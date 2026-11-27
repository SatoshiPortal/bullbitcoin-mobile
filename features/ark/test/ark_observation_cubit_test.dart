import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_usecase.dart';
import 'package:bull_ark/src/presentation/ark_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account;
import 'fake_ark_client.dart';

ArkSnapshot projection(int revision) => ArkSnapshot(
  account: account(),
  revision: revision,
  observedAt: DateTime.utc(2026, 11, 16),
  stale: false,
);

class DelayedRead extends FakeArkClient {
  final reply = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> read(ArkAccountId account) {
    calls.add('read');
    arguments.add(account);
    return reply.future;
  }
}

class DelayedRefresh extends FakeArkClient {
  final reply = Completer<Result<ArkPassOutcome, ArkWalletFailure>>();
  @override
  Future<Result<ArkPassOutcome, ArkWalletFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  }) => reply.future;
}

ArkCubit controller(FakeArkClient client) {
  final repository = ArkRepositoryImpl(client);
  return ArkCubit(
    ReadArkUsecase(repository),
    SynchronizeArkUsecase(repository),
    account: account(),
  );
}

void main() {
  test(
    'watch keeps the newest revision when an older read completes',
    () async {
      final changes =
          StreamController<Result<ArkSnapshot, ArkWalletFailure>>.broadcast();
      addTearDown(changes.close);
      final client = DelayedRead()..changes = changes.stream;
      final cubit = controller(client);
      addTearDown(cubit.close);
      final loading = cubit.load();
      await Future<void>.delayed(Duration.zero);
      changes.add(Ok(projection(3)));
      await Future<void>.delayed(Duration.zero);
      client.reply.complete(Ok(projection(1)));
      await loading;
      changes.add(Ok(projection(2)));
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as ArkObserved).snapshot.revision, 3);
    },
  );

  test('closing cancels the observation subscription', () async {
    var cancelled = false;
    final changes = StreamController<Result<ArkSnapshot, ArkWalletFailure>>(
      onCancel: () => cancelled = true,
    );
    addTearDown(changes.close);
    final client = FakeArkClient()
      ..snapshot = Ok(projection(1))
      ..changes = changes.stream;
    final cubit = controller(client);
    await cubit.load();
    await cubit.close();
    expect(cancelled, isTrue);
  });

  test('closing is synchronous but waits for observation cleanup', () async {
    final cancellation = Completer<void>();
    final changes = StreamController<Result<ArkSnapshot, ArkWalletFailure>>(
      onCancel: () => cancellation.future,
    );
    addTearDown(changes.close);
    addTearDown(() {
      if (!cancellation.isCompleted) cancellation.complete();
    });
    final client = FakeArkClient()
      ..snapshot = Ok(projection(1))
      ..changes = changes.stream;
    final cubit = controller(client);
    await cubit.load();
    var completed = false;
    final closing = cubit.close().then((_) => completed = true);
    expect(cubit.isClosed, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    cancellation.complete();
    await closing;
    expect(completed, isTrue);
  });

  test('a late refresh cannot replace a newer watched revision', () async {
    final changes =
        StreamController<Result<ArkSnapshot, ArkWalletFailure>>.broadcast();
    addTearDown(changes.close);
    final client = DelayedRefresh()
      ..snapshot = Ok(projection(1))
      ..changes = changes.stream;
    final cubit = controller(client);
    addTearDown(cubit.close);
    await cubit.load();
    final refreshing = cubit.refresh();
    changes.add(Ok(projection(3)));
    await Future<void>.delayed(Duration.zero);
    client.reply.complete(Ok(ArkPassOutcome(snapshot: projection(2))));
    await refreshing;
    expect((cubit.state as ArkObserved).snapshot.revision, 3);
  });

  for (final failed in [false, true]) {
    test(
      'late initial read failed=$failed cannot replace a newer refresh',
      () async {
        final client = DelayedRead()
          ..pass = Ok(ArkPassOutcome(snapshot: projection(2)));
        final cubit = controller(client);
        addTearDown(cubit.close);
        final loading = cubit.load();
        await cubit.refresh();
        client.reply.complete(
          failed ? const Err(ArkStorageFailure()) : Ok(projection(1)),
        );
        await loading;
        expect(
          cubit.state,
          isA<ArkObserved>().having(
            (s) => s.snapshot.revision,
            'newer revision',
            2,
          ),
        );
        expect(client.calls, ['read', 'sync']);
      },
    );
  }

  test('a closed controller starts no new read or native refresh', () async {
    final client = FakeArkClient()..snapshot = Ok(projection(1));
    final cubit = controller(client);
    await cubit.close();
    await cubit.load();
    await cubit.refresh();
    expect(client.calls, isEmpty);
  });

  test('repeated load shares one pending read', () async {
    final client = DelayedRead();
    final cubit = controller(client);
    addTearDown(cubit.close);
    final first = cubit.load();
    final second = cubit.load();
    client.reply.complete(Ok(projection(1)));
    await Future.wait([first, second]);
    expect(client.calls, ['read']);
    expect(cubit.state, isA<ArkObserved>());
  });

  test(
    'current refresh failure retains the last observed matching projection',
    () async {
      final previous = projection(1);
      final client = FakeArkClient()
        ..snapshot = Ok(previous)
        ..pass = const Err(ArkUnavailableFailure());
      final cubit = controller(client);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.refresh();
      expect(
        cubit.state,
        isA<ArkViewFailed>().having(
          (s) => s.lastObserved,
          'retained projection',
          same(previous),
        ),
      );
      expect(client.calls, ['read', 'sync']);
    },
  );

  test(
    'closing does not publish a late read or cancel its admitted future',
    () async {
      final client = DelayedRead();
      final cubit = controller(client);
      final pending = cubit.load();
      await cubit.close();
      client.reply.complete(Ok(projection(1)));
      await pending;
      expect(cubit.isClosed, true);
      expect(cubit.state, isA<ArkLoading>());
      expect(client.calls, ['read']);
    },
  );
}
