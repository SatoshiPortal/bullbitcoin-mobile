import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_notification_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetRecipientsEnvironmentUsecase extends Mock
    implements GetRecipientsEnvironmentUsecase {}

class _FakeExchangeNotificationRepository
    implements ExchangeNotificationRepository {
  final StreamController<NotificationMessage> controller =
      StreamController<NotificationMessage>.broadcast();

  @override
  Stream<NotificationMessage> get messages => controller.stream;

  @override
  Future<Result<void, ExchangeNotificationFailure>> connect() async =>
      const Ok(null);

  @override
  Future<Result<void, ExchangeNotificationFailure>> reconnect() async =>
      const Ok(null);

  @override
  void disconnect() {}
}

class _FakeVirtualIbanRepository implements VirtualIbanRepository {
  final List<Result<VirtualIban?, RecipientsFailure>> findResults;
  final Result<VirtualIban, RecipientsFailure> createResult;
  int finds = 0;
  int creates = 0;
  bool? lastIsTestnet;

  _FakeVirtualIbanRepository({
    required this.findResults,
    this.createResult = const Err(RecipientsUnexpectedFailure()),
  });

  @override
  Future<Result<VirtualIban?, RecipientsFailure>> find({
    required bool isTestnet,
  }) async {
    lastIsTestnet = isTestnet;
    return findResults[finds++];
  }

  @override
  Future<Result<VirtualIban, RecipientsFailure>> create({
    required bool isTestnet,
  }) async {
    creates++;
    return createResult;
  }
}

final _active = VirtualIban.fromBankDetails(
  iban: 'FR7616958000016918327146718',
  bicCode: 'FIRPFRP2',
  bankAddress: '1 Rue de la Paix, Paris',
);
const _pending = PendingVirtualIban();

void main() {
  late _MockGetRecipientsEnvironmentUsecase environment;
  late _FakeExchangeNotificationRepository notifications;

  setUp(() {
    environment = _MockGetRecipientsEnvironmentUsecase();
    notifications = _FakeExchangeNotificationRepository();
    when(
      () => environment.execute(),
    ).thenAnswer((_) async => const Ok(Environment.testnet));
  });

  tearDown(() => notifications.controller.close());

  WatchVirtualIbanUsecase usecase(
    _FakeVirtualIbanRepository repository, {
    Duration pollInterval = Duration.zero,
  }) => WatchVirtualIbanUsecase(
    virtualIbanRepository: repository,
    getRecipientsEnvironmentUsecase: environment,
    exchangeNotificationRepository: notifications,
    pollInterval: pollInterval,
  );

  test('reports no virtual IBAN without creating one', () async {
    final repository = _FakeVirtualIbanRepository(
      findResults: [const Ok(null)],
    );

    final events = await usecase(
      repository,
    ).execute(createIfAbsent: false).toList();

    expect(events.map((e) => (e as Ok).value), [null]);
    expect(repository.creates, 0);
    expect(repository.lastIsTestnet, isTrue);
  });

  test('creates a missing virtual IBAN and waits until it is active', () async {
    final repository = _FakeVirtualIbanRepository(
      findResults: [const Ok(null), const Ok(_pending), Ok(_active)],
      createResult: const Ok(_pending),
    );

    final events = await usecase(
      repository,
    ).execute(createIfAbsent: true).toList();

    expect(repository.creates, 1);
    expect(events.map((e) => (e as Ok).value), [_pending, _pending, _active]);
  });

  test('an active virtual IBAN is reported once', () async {
    final repository = _FakeVirtualIbanRepository(findResults: [Ok(_active)]);

    final events = await usecase(
      repository,
    ).execute(createIfAbsent: true).toList();

    expect(events.map((e) => (e as Ok).value), [_active]);
    expect(repository.creates, 0);
  });

  test('a failed creation is the last event', () async {
    final repository = _FakeVirtualIbanRepository(
      findResults: [const Ok(null)],
      createResult: const Err(RecipientsEuResidencyRequiredFailure()),
    );

    final events = await usecase(
      repository,
    ).execute(createIfAbsent: true).toList();

    expect(events, hasLength(1));
    expect(
      (events.single as Err).failure,
      isA<RecipientsEuResidencyRequiredFailure>(),
    );
  });

  test('a failed refresh stops the polling', () async {
    final repository = _FakeVirtualIbanRepository(
      findResults: [const Ok(_pending), const Err(RecipientsNetworkFailure())],
    );

    final events = await usecase(
      repository,
    ).execute(createIfAbsent: true).toList();

    expect(events, hasLength(2));
    expect((events.last as Err).failure, isA<RecipientsNetworkFailure>());
  });

  test(
    'a VIRTUAL_IBAN_ACTIVATED push re-checks before the poll fires',
    () async {
      final repository = _FakeVirtualIbanRepository(
        findResults: [const Ok(_pending), Ok(_active)],
      );

      // A long poll interval: only the websocket push can drive the re-check.
      final events = usecase(
        repository,
        pollInterval: const Duration(minutes: 10),
      ).execute(createIfAbsent: false);

      final collected = <Result<VirtualIban?, RecipientsFailure>>[];
      final done = Completer<void>();
      final sub = events.listen(collected.add, onDone: done.complete);

      // Let the first find() (pending) emit, then push the activation event.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      notifications.controller.add(
        NotificationMessage(
          kind: NotificationMessageKind.recipient,
          event: 'VIRTUAL_IBAN_ACTIVATED',
          rawData: const {
            'type': 'recipient',
            'event': 'VIRTUAL_IBAN_ACTIVATED',
          },
        ),
      );

      await done.future.timeout(const Duration(seconds: 2));
      await sub.cancel();

      expect(collected.map((e) => (e as Ok).value), [_pending, _active]);
      expect(repository.finds, 2);
    },
  );

  test('an unreadable environment is reported', () async {
    when(
      () => environment.execute(),
    ).thenAnswer((_) async => const Err(RecipientsUnexpectedFailure()));
    final repository = _FakeVirtualIbanRepository(findResults: []);

    final events = await usecase(
      repository,
    ).execute(createIfAbsent: true).toList();

    expect(events, hasLength(1));
    expect(repository.finds, 0);
  });
}
