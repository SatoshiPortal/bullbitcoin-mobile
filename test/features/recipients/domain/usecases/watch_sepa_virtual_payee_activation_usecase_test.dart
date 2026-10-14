import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetRecipientsEnvironmentUsecase extends Mock
    implements GetRecipientsEnvironmentUsecase {}

class _FakeSepaVirtualPayeeRepository implements SepaVirtualPayeeRepository {
  final List<Result<SepaVirtualPayeeStatus?, RecipientsFailure>> findResults;
  final Result<SepaVirtualPayeeStatus, RecipientsFailure> activateResult;
  int finds = 0;
  int activations = 0;
  bool? lastIsTestnet;

  _FakeSepaVirtualPayeeRepository({
    required this.findResults,
    this.activateResult = const Ok(SepaVirtualPayeeStatus.pending),
  });

  @override
  Future<Result<SepaVirtualPayeeStatus?, RecipientsFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  }) async {
    lastIsTestnet = isTestnet;
    return findResults[finds++];
  }

  @override
  Future<Result<SepaVirtualPayeeStatus, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) async {
    activations++;
    return activateResult;
  }
}

const _absent = Ok<SepaVirtualPayeeStatus?, RecipientsFailure>(
  SepaVirtualPayeeStatus.absent,
);
const _pending = Ok<SepaVirtualPayeeStatus?, RecipientsFailure>(
  SepaVirtualPayeeStatus.pending,
);
const _active = Ok<SepaVirtualPayeeStatus?, RecipientsFailure>(
  SepaVirtualPayeeStatus.active,
);

void main() {
  late _MockGetRecipientsEnvironmentUsecase environment;

  setUp(() {
    environment = _MockGetRecipientsEnvironmentUsecase();
    when(
      () => environment.execute(),
    ).thenAnswer((_) async => const Ok(Environment.testnet));
  });

  Future<List<Result<SepaVirtualPayeeStatus, RecipientsFailure>>> run(
    _FakeSepaVirtualPayeeRepository repository,
  ) => WatchSepaVirtualPayeeActivationUsecase(
    sepaVirtualPayeeRepository: repository,
    getRecipientsEnvironmentUsecase: environment,
    initialPollInterval: Duration.zero,
    pollInterval: Duration.zero,
  ).execute(recipientId: 'r-1').toList();

  List<SepaVirtualPayeeStatus> statuses(
    List<Result<SepaVirtualPayeeStatus, RecipientsFailure>> events,
  ) => [
    for (final e in events)
      (e as Ok<SepaVirtualPayeeStatus, RecipientsFailure>).value,
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

  test('a failed activation is the last event', () async {
    final repository = _FakeSepaVirtualPayeeRepository(
      findResults: [_absent],
      activateResult: const Err(RecipientsUnexpectedFailure()),
    );

    final events = await run(repository);

    expect(events, hasLength(2));
    expect(
      (events.first as Ok<SepaVirtualPayeeStatus, RecipientsFailure>).value,
      SepaVirtualPayeeStatus.absent,
    );
    expect(events.last, isA<Err<SepaVirtualPayeeStatus, RecipientsFailure>>());
    expect(repository.finds, 1);
  });

  test('a failed refresh stops the polling', () async {
    final repository = _FakeSepaVirtualPayeeRepository(
      findResults: [_pending, const Err(RecipientsNetworkFailure())],
    );

    final events = await run(repository);

    expect(events, hasLength(2));
    expect(
      (events.last as Err<SepaVirtualPayeeStatus, RecipientsFailure>).failure,
      isA<RecipientsNetworkFailure>(),
    );
  });

  test('a recipient that is not found is a failure', () async {
    final repository = _FakeSepaVirtualPayeeRepository(
      findResults: [const Ok(null)],
    );

    final events = await run(repository);

    expect(
      events.single,
      isA<Err<SepaVirtualPayeeStatus, RecipientsFailure>>(),
    );
    expect(repository.activations, 0);
  });
}
