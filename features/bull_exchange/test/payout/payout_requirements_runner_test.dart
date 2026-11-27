import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'payout_requirements_fakes.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 3,
  sessionId: 's',
);

void main() {
  late List<String> calls;
  late List<ExchangeSession> sessions;
  late List<RequirementsEvent> events;
  late PayoutRequirementsRunner runner;

  PayoutRequirementsUsecases fakeUsecases() => PayoutRequirementsUsecases(
    loadVirtualIban: FakeLoadVirtualIbanContextUsecase((session) async {
      sessions.add(session);
      calls.add('load');
      return const ReadGot(
        VirtualIbanContext(virtualIban: null, ownerName: 'Ada Lovelace'),
      );
    }),
    createVirtualIban: FakeCreateVirtualIbanUsecase((session) async {
      sessions.add(session);
      calls.add('create');
      return const WriteOutcomeUnknown('lost');
    }),
    findVirtualIban: FakeFindVirtualIbanUsecase((session) async {
      sessions.add(session);
      calls.add('find');
      return const ReadGot(null);
    }),
    payeeStatus: FakeGetVirtualPayeeStatusUsecase((session, id) async {
      sessions.add(session);
      calls.add('status $id');
      return const ReadGot(SepaVirtualPayeeStatus.pending);
    }),
    activatePayee: FakeActivateVirtualPayeeUsecase((session, id) async {
      sessions.add(session);
      calls.add('activate $id');
      return const WriteDone(SepaVirtualPayeeStatus.pending);
    }),
  );

  setUp(() {
    calls = [];
    sessions = [];
    events = [];
    runner = PayoutRequirementsRunner(fakeUsecases(), _session, events.add);
  });

  test('each virtual IBAN effect answers its event with its attempt', () {
    fakeAsync((async) {
      runner.run(const [
        RequirementVirtualIbanEffect(VibanLoad(1)),
        RequirementVirtualIbanEffect(VibanCreate(2)),
        RequirementVirtualIbanEffect(VibanVerify(3)),
      ]);
      async.flushMicrotasks();
      expect(calls, ['load', 'create', 'find']);
      expect(sessions, everyElement(_session));
      expect(events, [
        isA<RequirementVirtualIbanEvent>().having(
          (e) => e.event,
          'event',
          isA<VibanLoaded>().having((e) => e.attempt, 'attempt', 1),
        ),
        isA<RequirementVirtualIbanEvent>().having(
          (e) => e.event,
          'event',
          isA<VibanCreated>().having((e) => e.attempt, 'attempt', 2),
        ),
        isA<RequirementVirtualIbanEvent>().having(
          (e) => e.event,
          'event',
          isA<VibanVerified>().having((e) => e.attempt, 'attempt', 3),
        ),
      ]);
    });
  });

  test('a poll waits its interval, carries its ticket, and stops on '
      'StopWatching', () {
    fakeAsync((async) {
      runner.run(const [
        RequirementVirtualIbanEffect(VibanSchedulePoll(4)),
        RequirementVirtualIbanEffect(
          VibanStartDeadline(1, Duration(minutes: 1)),
        ),
      ]);
      async.elapse(const Duration(seconds: 4));
      expect(calls, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(calls, ['find']);
      expect(
        (events.single as RequirementVirtualIbanEvent).event,
        isA<VibanPolled>().having((e) => e.ticket, 'ticket', 4),
      );
      runner.run(const [
        RequirementVirtualIbanEffect(VibanSchedulePoll(5)),
        RequirementVirtualIbanEffect(VibanStopWatching()),
      ]);
      async.elapse(const Duration(minutes: 2));
      expect(calls, ['find']);
      expect(events, hasLength(1));
    });
  });

  test('payee effects run for the recipient they carry', () {
    fakeAsync((async) {
      runner.run(const [
        RequirementVirtualPayeeEffect('r-1', PayeeLoad(1)),
        RequirementVirtualPayeeEffect('r-1', PayeeActivate(1)),
        RequirementVirtualPayeeEffect(
          'r-1',
          PayeeSchedulePoll(2, Duration(seconds: 1)),
        ),
        RequirementVirtualPayeeEffect(
          'r-1',
          PayeeStartDeadline(1, Duration(seconds: 3)),
        ),
      ]);
      async.elapse(const Duration(seconds: 3));
      expect(calls, ['status r-1', 'activate r-1', 'status r-1']);
      expect(sessions, everyElement(_session));
      expect(events.map((e) => (e as RequirementVirtualPayeeEvent).event), [
        isA<PayeeLoaded>(),
        isA<PayeeActivated>(),
        isA<PayeePolled>().having((e) => e.ticket, 'ticket', 2),
        isA<PayeeDeadlinePassed>().having((e) => e.round, 'round', 1),
      ]);
    });
  });

  test('nothing answers after close', () {
    fakeAsync((async) {
      runner.run(const [RequirementVirtualIbanEffect(VibanSchedulePoll(1))]);
      runner.close();
      async.elapse(const Duration(minutes: 1));
      expect(calls, isEmpty);
      expect(events, isEmpty);
    });
  });

  group('answers', () {
    test('a failure is never read as a value', () {
      expect(
        readOfResult<int>(const Err(ExchangeNetworkFailure())),
        isA<ReadUnreachable<int>>().having((r) => r.isNetwork, 'net', true),
      );
      expect(
        readOfResult<int>(
          const Err(
            ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
          ),
        ),
        isA<ReadSessionRejected<int>>(),
      );
      expect(
        readOfResult<int>(const Ok(1)),
        isA<ReadGot<int>>().having((r) => r.value, 'value', 1),
      );
    });

    test('a write failure that may have reached the server is unknown', () {
      expect(
        writeOfResult<int>(const Err(ExchangeNetworkFailure())),
        isA<WriteOutcomeUnknown<int>>(),
      );
      expect(
        writeOfResult<int>(const Err(ExchangeUnexpectedFailure())),
        isA<WriteOutcomeUnknown<int>>(),
      );
      expect(
        writeOfResult<int>(const Err(ExchangeNotAuthenticatedFailure())),
        isA<WriteNotSent<int>>(),
      );
      expect(
        writeOfResult<int>(
          const Err(ExchangeOrderRejectedFailure(apiCode: 'X')),
        ),
        isA<WriteRefused<int>>(),
      );
    });
  });
}
