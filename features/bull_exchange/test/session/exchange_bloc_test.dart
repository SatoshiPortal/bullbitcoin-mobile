import 'dart:async';

import 'package:bull_exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../account/account_usecase_fakes.dart';
import '../dca/dca_usecase_fakes.dart';
import 'session_usecase_fakes.dart';

const _a = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const _b = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 2,
  sessionId: 'b',
);

const _account = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [],
  dca: UserDca(isActive: true),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

/// Scripted answers, one queue per call kind.
final class _Server {
  final accounts = <Completer<Result<UserSummary, ExchangeFailure>>>[];
  final accountSessions = <ExchangeSession>[];
  final stops = <Completer<Result<void, ExchangeFailure>>>[];
  var reconciliations = 0;

  Future<Result<UserSummary, ExchangeFailure>> account(ExchangeSession s) {
    accountSessions.add(s);
    final answer = Completer<Result<UserSummary, ExchangeFailure>>();
    accounts.add(answer);
    return answer.future;
  }

  Future<Result<void, ExchangeFailure>> stop(ExchangeSession _) {
    final answer = Completer<Result<void, ExchangeFailure>>();
    stops.add(answer);
    return answer.future;
  }
}

void main() {
  late _Server server;
  late StreamController<ExchangeAccess> access;
  late StreamController<NotificationMessage> pushes;
  ExchangeAccess current = const ExchangeAccessDisabled();

  ExchangeBloc build() => ExchangeBloc(
    currentAccess: () => current,
    accessChanges: access.stream,
    accountChanges: pushes.stream,
    getAccount: FakeGetAccountUsecase(server.account),
    getAnnouncements: FakeGetAnnouncementsUsecase((_) async => const Ok([])),
    stopDca: FakeStopDcaUsecase(server.stop),
    reconcileUnknownWrites: FakeReconcileUnknownWritesUsecase(() async {
      server.reconciliations++;
      return const Ok(UnknownWriteReconciliation(settled: 0, open: 0));
    }),
  );

  Future<void> publish(ExchangeAccess value) async {
    current = value;
    access.add(value);
    await pumpEventQueue();
  }

  setUp(() {
    server = _Server();
    current = const ExchangeAccessDisabled();
    access = StreamController<ExchangeAccess>.broadcast();
    pushes = StreamController<NotificationMessage>.broadcast();
  });

  tearDown(() async {
    await access.close();
    await pushes.close();
  });

  test(
    'a new session loads and reconciles once; the same one does not',
    () async {
      final bloc = build();
      addTearDown(bloc.close);
      await publish(const ExchangeAccessSignedIn(_a));
      await publish(const ExchangeAccessSignedIn(_a));

      expect(bloc.state, const ExchangeLoading(_a));
      expect(server.accountSessions, [_a]);
      expect(server.reconciliations, 1);

      server.accounts.single.complete(const Ok(_account));
      await pumpEventQueue();
      expect(bloc.state, isA<ExchangeLoaded>());
    },
  );

  test('a late answer of the previous account is never shown (B1)', () async {
    final bloc = build();
    addTearDown(bloc.close);
    await publish(const ExchangeAccessSignedIn(_a));
    await publish(const ExchangeAccessSignedIn(_b));
    server.accounts.first.complete(const Ok(_account));
    await pumpEventQueue();

    expect(bloc.state, const ExchangeLoading(_b));
    expect(server.reconciliations, 2);
  });

  test('pushes during a refresh start no second request (B10)', () async {
    final bloc = build();
    addTearDown(bloc.close);
    await publish(const ExchangeAccessSignedIn(_a));
    server.accounts.single.complete(const Ok(_account));
    await pumpEventQueue();

    for (var i = 0; i < 3; i++) {
      pushes.add(const NotificationMessage(kind: NotificationMessageKind.kyc));
    }
    await pumpEventQueue();

    expect(server.accounts, hasLength(2));
    expect((bloc.state as ExchangeLoaded).refresh, const Refreshing());
  });

  test('retry after a failed load always reads again (B4)', () async {
    final bloc = build();
    addTearDown(bloc.close);
    await publish(const ExchangeAccessSignedIn(_a));
    server.accounts.single.complete(const Err(ExchangeOperationStaleFailure()));
    await pumpEventQueue();
    expect(bloc.state, isA<ExchangeLoadFailed>());

    bloc.add(const ExchangeRefreshRequested());
    await pumpEventQueue();

    expect(bloc.state, const ExchangeLoading(_a));
    expect(server.accounts, hasLength(2));
  });

  test('a DCA stop failure does not outlive the session (B3)', () async {
    final bloc = build();
    addTearDown(bloc.close);
    await publish(const ExchangeAccessSignedIn(_a));
    server.accounts.single.complete(const Ok(_account));
    await pumpEventQueue();
    bloc
      ..add(const ExchangeStopDcaRequested())
      ..add(const ExchangeStopDcaRequested());
    await pumpEventQueue();
    expect(server.stops, hasLength(1));
    server.stops.single.complete(const Err(ExchangeNetworkFailure()));
    await pumpEventQueue();
    expect(
      (bloc.state as ExchangeLoaded).dcaStop,
      const DcaStopFailed(ExchangeNetworkFailure()),
    );

    await publish(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    expect(bloc.state, const ExchangeSignedOut());
    await publish(const ExchangeAccessSignedIn(_b));
    expect(bloc.state, const ExchangeLoading(_b));
  });

  test('a stopped DCA refreshes the summary', () async {
    final bloc = build();
    addTearDown(bloc.close);
    await publish(const ExchangeAccessSignedIn(_a));
    server.accounts.single.complete(const Ok(_account));
    await pumpEventQueue();
    bloc.add(const ExchangeStopDcaRequested());
    await pumpEventQueue();
    server.stops.single.complete(const Ok(null));
    await pumpEventQueue();

    expect(server.accounts, hasLength(2));
    expect((bloc.state as ExchangeLoaded).refresh, const Refreshing());
  });
}
