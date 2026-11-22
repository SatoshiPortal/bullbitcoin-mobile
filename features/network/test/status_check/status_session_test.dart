import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/network.dart';
import 'package:network/src/status_check/domain/check_service_status_usecase.dart';
import 'package:network/src/status_check/status_session.dart';
import 'package:primitives/primitives.dart';

class _CheckStatus extends Mock implements CheckServiceStatusUsecase {}

extension<T> on Result<T, NetworkFailure> {
  T get unwrap =>
      fold((value) => value, (failure) => fail('Unexpected failure: $failure'));
  NetworkFailure get unwrapErr =>
      fold((value) => fail('Unexpected success: $value'), (failure) => failure);
}

void main() {
  const online = ServiceStatusInfo(status: ServiceStatus.online);
  const offline = ServiceStatusInfo(status: ServiceStatus.offline);
  const partial = AllServicesStatus(liquidElectrum: online);

  late _CheckStatus check;
  late NetworkStatus status;
  late StatusSession session;
  late List<Completer<Result<AllServicesStatus, NetworkFailure>>> checks;
  late List<void Function(AllServicesStatus)> publish;

  setUpAll(() {
    registerFallbackValue(const AllServicesStatus());
    registerFallbackValue((AllServicesStatus _) {});
  });

  setUp(() {
    check = _CheckStatus();
    checks = [];
    publish = [];
    when(
      () => check.execute(
        initialStatus: any(named: 'initialStatus'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenAnswer((invocation) {
      final pending = Completer<Result<AllServicesStatus, NetworkFailure>>();
      checks.add(pending);
      publish.add(
        invocation.namedArguments[#onUpdate]
            as void Function(AllServicesStatus),
      );
      return pending.future;
    });
    status = buildNetworkStatus(() => check);
    session = status.session();
    addTearDown(session.close);
  });

  test(
    'watch replays idle without starting a probe and emits partial rows',
    () async {
      final updates = StreamIterator(session.watch());
      addTearDown(updates.cancel);
      expect(await updates.moveNext(), isTrue);
      expect(updates.current.unwrap.isRefreshing, isFalse);
      expect(checks, isEmpty);

      final pending = session.check();
      expect(await updates.moveNext(), isTrue);
      expect(updates.current.unwrap.isRefreshing, isTrue);
      publish.single(partial);
      expect(await updates.moveNext(), isTrue);
      expect(updates.current.unwrap.services, partial);
      expect(updates.current.unwrap.isRefreshing, isTrue);

      final done = partial.copyWith(
        bitcoinElectrum: online,
        lastChecked: DateTime(2026),
      );
      checks.single.complete(Ok(done));
      expect((await pending).unwrap, done);
      expect(await updates.moveNext(), isTrue);
      expect(updates.current.unwrap.services, done);
      expect(updates.current.unwrap.isRefreshing, isFalse);
    },
  );

  test(
    'latest refresh wins while other sessions complete independently',
    () async {
      final other = status.session();
      addTearDown(other.close);
      final updates = <Result<StatusSnapshot, NetworkFailure>>[];
      final listener = session.watch().listen(updates.add);
      addTearDown(listener.cancel);
      final first = session.check();
      final separate = other.check();
      final latest = session.check();
      const stale = AllServicesStatus(bitcoinElectrum: offline);

      checks[2].complete(const Ok(partial));
      expect((await latest).unwrap, partial);
      publish[0](stale);
      checks[0].complete(const Ok(stale));
      expect(await first, isA<Err<AllServicesStatus, NetworkFailure>>());
      expect(session.snapshot.services, partial);
      expect(session.snapshot.isRefreshing, isFalse);
      expect(
        updates.map((update) => update.unwrap.services),
        isNot(contains(stale)),
      );

      checks[1].complete(const Ok(stale));
      expect((await separate).unwrap, stale);
      expect(other.snapshot.services, stale);
    },
  );

  test('retains rows across refresh and replays a terminal failure', () async {
    final first = session.check();
    checks[0].complete(const Ok(partial));
    expect((await first).unwrap, partial);

    final second = session.check();
    expect(session.snapshot.services, partial);
    expect(session.snapshot.isRefreshing, isTrue);
    const failure = NoDefaultWalletFailure();
    checks[1].complete(const Err(failure));
    expect((await second).unwrapErr, failure);

    final updates = await session.watch().take(2).toList();
    expect(updates.first.unwrap.services, partial);
    expect(updates.first.unwrap.isRefreshing, isFalse);
    expect(updates.last.unwrapErr, failure);
  });

  test(
    'closing a session ends observation before a pending check completes',
    () async {
      final updates = session.watch().toList();
      final pending = session.check();
      await session.close();
      publish.single(partial);
      checks.single.complete(const Ok(partial));

      expect((await pending).unwrapErr, isA<StatusCheckInterruptedFailure>());
      expect(
        (await session.check()).unwrapErr,
        isA<StatusCheckInterruptedFailure>(),
      );
      expect(await session.watch().toList(), isEmpty);
      expect((await updates).map((update) => update.unwrap.services), [
        const AllServicesStatus(),
        const AllServicesStatus(),
      ]);
      expect(checks, hasLength(1));
    },
  );
}
