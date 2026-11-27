import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetRecipientsEnvironmentUsecase extends Mock
    implements GetRecipientsEnvironmentUsecase {}

class _FakeSepaVirtualPayeeRepository extends Fake
    implements RecipientsRepository {
  final List<Result<SepaVirtualPayeeStatus?, ExchangeFailure>> findResults;
  final Result<SepaVirtualPayeeStatus, ExchangeFailure> activateResult;
  int finds = 0;
  int activations = 0;
  bool? lastIsTestnet;

  _FakeSepaVirtualPayeeRepository({
    required this.findResults,
    this.activateResult = const Ok(SepaVirtualPayeeStatus.pending),
  });

  @override
  Future<Result<SepaVirtualPayeeStatus?, ExchangeFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  }) async {
    lastIsTestnet = isTestnet;
    return findResults[finds++];
  }

  @override
  Future<Result<SepaVirtualPayeeStatus, ExchangeFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) async {
    activations++;
    return activateResult;
  }
}

const _absent = Ok<SepaVirtualPayeeStatus?, ExchangeFailure>(
  SepaVirtualPayeeStatus.absent,
);
const _pending = Ok<SepaVirtualPayeeStatus?, ExchangeFailure>(
  SepaVirtualPayeeStatus.pending,
);
const _active = Ok<SepaVirtualPayeeStatus?, ExchangeFailure>(
  SepaVirtualPayeeStatus.active,
);
const _unknown = Ok<SepaVirtualPayeeStatus?, ExchangeFailure>(
  SepaVirtualPayeeStatus.unknown,
);

void main() {
  late _MockGetRecipientsEnvironmentUsecase environment;

  setUp(() {
    environment = _MockGetRecipientsEnvironmentUsecase();
    when(() => environment.execute())
        .thenAnswer((_) async => const Ok(Environment.testnet));
  });

  Future<List<Result<SepaVirtualPayeeStatus, ExchangeFailure>>> run(
    _FakeSepaVirtualPayeeRepository repository,
  ) => WatchSepaVirtualPayeeActivationUsecase(
    sepaVirtualPayeeRepository: repository,
    getRecipientsEnvironmentUsecase: environment,
    initialPollInterval: Duration.zero,
    pollInterval: Duration.zero,
  ).execute(recipientId: 'r-1').toList();

  List<SepaVirtualPayeeStatus> statuses(
    List<Result<SepaVirtualPayeeStatus, ExchangeFailure>> events,
  ) => [
    for (final e in events)
      (e as Ok<SepaVirtualPayeeStatus, ExchangeFailure>).value,
  ];

  test(
    'an already-active recipient reports active without activating',
    () async {
      final repository = _FakeSepaVirtualPayeeRepository(
        findResults: [_active],
      );

      final events = await run(repository);

      expect(statuses(events), [SepaVirtualPayeeStatus.active]);
      expect(repository.activations, 0);
      expect(repository.lastIsTestnet, isTrue);
    },
  );

  test('activates a recipient without a virtual payee and waits', () async {
    final repository = _FakeSepaVirtualPayeeRepository(
      findResults: [_absent, _pending, _pending, _active],
    );

    final events = await run(repository);

    expect(repository.activations, 1);
    expect(statuses(events), [
      SepaVirtualPayeeStatus.absent,
      SepaVirtualPayeeStatus.pending,
      SepaVirtualPayeeStatus.active,
    ]);
  });

  test('waits for a pending recipient without activating it again', () async {
    final repository = _FakeSepaVirtualPayeeRepository(
      findResults: [_pending, _active],
    );

    final events = await run(repository);

    expect(repository.activations, 0);
    expect(statuses(events), [
      SepaVirtualPayeeStatus.pending,
      SepaVirtualPayeeStatus.active,
    ]);
  });

  test('an unknown status is the last event: no more polls, no activation '
      '(RCP-11)', () async {
    final repository = _FakeSepaVirtualPayeeRepository(
      findResults: [_pending, _unknown, _active],
    );

    final events = await run(repository);

    expect(statuses(events), [
      SepaVirtualPayeeStatus.pending,
      SepaVirtualPayeeStatus.unknown,
    ]);
    expect(repository.finds, 2);
    expect(repository.activations, 0);
  });

  test('a failed activation is the last event', () async {
    final repository = _FakeSepaVirtualPayeeRepository(
      findResults: [_absent],
      activateResult: const Err(ExchangeUnexpectedFailure()),
    );

    final events = await run(repository);

    expect(events, hasLength(2));
    expect(
      (events.first as Ok<SepaVirtualPayeeStatus, ExchangeFailure>).value,
      SepaVirtualPayeeStatus.absent,
    );
    expect(events.last, isA<Err<SepaVirtualPayeeStatus, ExchangeFailure>>());
    expect(repository.finds, 1);
  });

  test('a failed refresh stops the polling', () async {
    final repository = _FakeSepaVirtualPayeeRepository(
      findResults: [_pending, const Err(ExchangeNetworkFailure())],
    );

    final events = await run(repository);

    expect(events, hasLength(2));
    expect(
      (events.last as Err<SepaVirtualPayeeStatus, ExchangeFailure>).failure,
      isA<ExchangeNetworkFailure>(),
    );
  });

  test('a recipient that is not found is a failure', () async {
    final repository = _FakeSepaVirtualPayeeRepository(
      findResults: [const Ok(null)],
    );

    final events = await run(repository);

    expect(events.single, isA<Err<SepaVirtualPayeeStatus, ExchangeFailure>>());
    expect(repository.activations, 0);
  });
}
