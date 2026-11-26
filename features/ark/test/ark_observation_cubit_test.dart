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

ArkCubit controller(FakeArkClient client) {
  final repository = ArkRepositoryImpl(client);
  return ArkCubit(
    ReadArkUsecase(repository),
    SynchronizeArkUsecase(repository),
    account: account(),
  );
}

void main() {
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
