import 'dart:async';

import 'package:bull_recoverbull/src/data/backup_metadata_repository_impl.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/entities/backup_settings.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_session_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/open_key_server_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  late RecoverBullDatabase database;
  late BackupMetadataRepositoryImpl settings;
  late _Sessions sessions;
  late OpenKeyServerUsecase open;

  Future<BackupSettings> current() async => switch (await settings.settings()) {
    Ok(:final value) => value,
    Err() => throw StateError('Fixture settings unavailable'),
  };

  setUp(() async {
    database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.forceOpen();
    settings = BackupMetadataRepositoryImpl(database);
    sessions = _Sessions();
    open = OpenKeyServerUsecase(settings, sessions);
  });
  tearDown(() => database.close());

  test(
    'no Tor acquisition before permission, even with monitoring enabled',
    () async {
      final expected = await current();
      expect(expected.monitoringEnabled, isTrue);
      expect(
        await open.execute(expected: expected, monitoring: true),
        isA<Err>(),
      );
      expect(sessions.opens, 0);
      expect(await settings.acceptServer(expected.server), isA<Ok>());
      expect(
        await open.execute(expected: await current(), monitoring: true),
        isA<Ok>(),
      );
      expect(sessions.opens, 1);
    },
  );

  test(
    'monitoring opt-out does not disable an explicit recovery flow',
    () async {
      expect(await settings.acceptServer((await current()).server), isA<Ok>());
      expect(await settings.setMonitoring(false), isA<Ok>());
      final expected = await current();
      expect(
        await open.execute(expected: expected, monitoring: true),
        isA<Err>(),
      );
      expect(sessions.opens, 0);
      expect(await open.execute(expected: expected), isA<Ok>());
    },
  );

  test('server change during acquisition closes the old route', () async {
    expect(await settings.acceptServer((await current()).server), isA<Ok>());
    final pending =
        Completer<Result<KeyServerRepository, RecoverBullFailure>>();
    sessions.pending = pending;
    final opening = open.execute(expected: await current());
    await sessions.started.future;
    expect(
      await settings.changeServer(Uri.parse('http://other.onion')),
      isA<Ok>(),
    );
    pending.complete(Ok(sessions.connection));
    expect(await opening, isA<Err>());
    expect(sessions.connection.closes, 1);
    expect((await current()).permissionGranted, isFalse);
  });
}

final class _Sessions implements KeyServerSessionRepository {
  final connection = _Connection();
  final started = Completer<void>();
  Completer<Result<KeyServerRepository, RecoverBullFailure>>? pending;
  int opens = 0;

  @override
  Future<Result<KeyServerRepository, RecoverBullFailure>> open(
    Uri server, {
    bool restartEmbedded = false,
  }) async {
    opens++;
    if (!started.isCompleted) started.complete();
    return pending?.future ?? Future.value(Ok(connection));
  }
}

final class _Connection extends Fake implements KeyServerRepository {
  int closes = 0;

  @override
  Future<void> close() async => closes++;
}
