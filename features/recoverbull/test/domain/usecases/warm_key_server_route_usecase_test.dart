import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_status.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/check_server_connection_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/warm_key_server_route_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../support/log_sink.dart';

class _MockRepository extends Mock implements RecoverBullRepository {}

class _MockCheck extends Mock implements CheckServerConnectionUsecase {}

void main() {
  late _MockRepository repository;
  late _MockCheck check;
  late TestLogSink log;
  late WarmKeyServerRouteUsecase usecase;

  final withBackup = RecoverBullStatus(
    lastEncryptedBackupAt: DateTime.utc(2026, 10, 1),
  );

  setUp(() {
    repository = _MockRepository();
    check = _MockCheck();
    log = TestLogSink.recording();
    usecase = WarmKeyServerRouteUsecase(
      repository: repository,
      check: check,
      log: log,
    );
  });

  test('sends exactly one probe for a user with an encrypted backup', () async {
    when(
      () => repository.fetchBackupStatus(RecoverBullNetwork.mainnet),
    ).thenAnswer((_) async => withBackup);
    when(() => check.execute()).thenAnswer((_) async => const Ok(true));

    await usecase.execute();

    verify(() => check.execute()).called(1);
    expect(
      log.entries.map((entry) => entry.message),
      contains('recoverbull.key_server.warmup.succeeded'),
    );
  });

  test('never contacts the key server without an encrypted backup', () async {
    when(
      () => repository.fetchBackupStatus(RecoverBullNetwork.mainnet),
    ).thenAnswer((_) async => const RecoverBullStatus.initial());

    await usecase.execute();

    verifyNever(() => check.execute());
  });

  test('never contacts the key server when the status is unknown', () async {
    when(
      () => repository.fetchBackupStatus(RecoverBullNetwork.mainnet),
    ).thenAnswer((_) async => const RecoverBullStatus.unavailable());

    await usecase.execute();

    verifyNever(() => check.execute());
  });

  test('logs a failed probe by type only', () async {
    when(
      () => repository.fetchBackupStatus(RecoverBullNetwork.mainnet),
    ).thenAnswer((_) async => withBackup);
    when(() => check.execute()).thenAnswer(
      (_) async =>
          const Err(KeyServerUnavailableFailure('http://secret.onion down')),
    );

    await usecase.execute();

    final messages = log.entries.map((entry) => entry.message).toList();
    expect(
      messages,
      contains(
        'recoverbull.key_server.warmup.failed '
        'failure_type=KeyServerUnavailableFailure',
      ),
    );
    expect(messages.join(), isNot(contains('onion')));
    expect(log.entries.every((entry) => entry.error == null), isTrue);
  });

  test('never throws, even when reading the status fails', () async {
    when(
      () => repository.fetchBackupStatus(RecoverBullNetwork.mainnet),
    ).thenThrow(StateError('database closed'));

    await expectLater(usecase.execute(), completes);

    verifyNever(() => check.execute());
    expect(
      log.entries.map((entry) => entry.message),
      contains('recoverbull.key_server.warmup.failed error_type=StateError'),
    );
  });
}
