import 'dart:async';
import 'dart:convert';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/data/datasources/google_drive_datasource.dart';
import 'package:bull_recoverbull/src/data/google_drive_backup_discovery_adapter.dart';
import 'package:bull_recoverbull/src/data/google_drive_repository.dart';
import 'package:bull_recoverbull/src/data/models/drive_file_metadata_model.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/entities/monitored_backup.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/discover_drive_backups_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../support/monitoring_repository.dart';

void main() {
  for (final empty in [true, false]) {
    test(
      'stale ${empty ? 'empty' : 'nonempty'} listing cannot replace the new account monitoring',
      () async {
        final database = RecoverBullDatabase.forTesting(
          NativeDatabase.memory(),
        );
        addTearDown(database.close);
        await database.ensureState();
        final store = RecoverBullAttemptMonitoringStore(database);
        await store.registerBackup(
          [2],
          origin: MonitoredBackupOrigin.drive,
          driveAccount: 'second@example.invalid',
          driveFileId: 'new-account-file',
        );
        final state = _DriveState();
        state.listPage = (_) async {
          // Another consumer changes the signed-in account during a request.
          state.account = 'second@example.invalid';
          return GoogleDriveMetadataPage(
            files: empty ? [] : [_file('old-account-file')],
          );
        };
        final result = await DiscoverDriveBackupsUsecase(
          drive: GoogleDriveBackupDiscoveryAdapter(_repository(state)),
          store: monitoringRepository(store),
        ).execute().requireOk();
        expect(result.status, DriveDiscoveryStatus.failed);
        expect(
          await store.driveBackups('second@example.invalid'),
          hasLength(1),
        );
        expect(await store.driveBackups('first@example.invalid'), isEmpty);
        expect(state.interactiveSignIns, 0);
        expect(state.signOuts, 0);
      },
    );
  }

  test('foreground download enters between discovery metadata pages', () async {
    final state = _DriveState();
    final firstPageStarted = Completer<void>();
    final firstPage = Completer<GoogleDriveMetadataPage>();
    state.listPage = (token) async {
      state.operations.add('page:${token ?? 'first'}');
      if (token == null) {
        firstPageStarted.complete();
        return firstPage.future;
      }
      return GoogleDriveMetadataPage(files: [_file('second')]);
    };
    final repository = _repository(state);
    final discovery = repository.withDiscoverySession((session) async {
      expect(await session!.fetchAllMetadata(), hasLength(2));
    });
    await firstPageStarted.future;
    final foreground = repository.fetchRawFile('foreground');
    firstPage.complete(
      GoogleDriveMetadataPage(files: [_file('first')], nextPageToken: 'second'),
    );
    await discovery;
    expect(await foreground, isA<Ok<String, RecoverBullFailure>>());
    expect(state.operations, [
      'page:first',
      'download:foreground',
      'page:second',
    ]);
    expect(state.interactiveSignIns, 0);
    expect(state.signOuts, 0);
  });

  test('foreground trash enters between discovery downloads', () async {
    final state = _DriveState();
    final firstDownloadStarted = Completer<void>();
    final firstDownload = Completer<List<int>>();
    state.download = (id) async {
      state.operations.add('download:$id');
      if (id == 'first') {
        firstDownloadStarted.complete();
        return firstDownload.future;
      }
      return utf8.encode('second');
    };
    final repository = _repository(state);
    final discovery = repository.withDiscoverySession((session) async {
      await session!.fetchRawFile('first');
      await session.fetchRawFile('second');
    });
    await firstDownloadStarted.future;
    final foreground = repository.trash('foreground');
    firstDownload.complete(utf8.encode('first'));
    await discovery;
    expect(await foreground, isA<Ok<Null, RecoverBullFailure>>());
    expect(state.operations, [
      'download:first',
      'trash:foreground',
      'download:second',
    ]);
  });

  test('account switch rejects stale reads and reconciliation', () async {
    final state = _DriveState();
    final sessionOpened = Completer<GoogleDriveDiscoverySession>();
    final resume = Completer<void>();
    var reconciled = false;
    final repository = _repository(state);
    final discovery = repository.withDiscoverySession((session) async {
      sessionOpened.complete(session!);
      await resume.future;
      await expectLater(
        session.fetchRawFile('old-account'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        session.withCurrentAccount(() async => reconciled = true),
        throwsA(isA<Exception>()),
      );
    });
    await sessionOpened.future;
    state.nextInteractiveAccount = 'second@example.invalid';
    expect(await repository.connect(), isA<Ok<Null, RecoverBullFailure>>());
    resume.complete();
    await discovery;
    expect(reconciled, isFalse);
    expect(state.operations, isEmpty);
    expect(state.account, 'second@example.invalid');
  });

  test(
    'silent account change rejects discovery without prompting or signing out',
    () async {
      final state = _DriveState();
      final repository = _repository(state);
      await repository.withDiscoverySession((session) async {
        state.account = 'second@example.invalid';
        await expectLater(
          session!.fetchRawFile('old-account'),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          session.withCurrentAccount(() async => null),
          throwsA(isA<Exception>()),
        );
      });
      expect(state.operations, isEmpty);
      expect(state.interactiveSignIns, 0);
      expect(state.signOuts, 0);
    },
  );

  test(
    'reconciliation holds its account only until the short commit finishes',
    () async {
      final state = _DriveState();
      final commitStarted = Completer<void>();
      final commit = Completer<void>();
      final repository = _repository(state);
      var connectionFinished = false;
      final discovery = repository.withDiscoverySession((session) async {
        await session!.withCurrentAccount(() async {
          commitStarted.complete();
          await commit.future;
          expect(state.account, session.account);
        });
      });
      await commitStarted.future;
      state.nextInteractiveAccount = 'second@example.invalid';
      final foreground = repository.connect().then((result) {
        connectionFinished = true;
        return result;
      });
      await Future<void>.delayed(Duration.zero);
      expect(connectionFinished, isFalse);
      commit.complete();
      await discovery;
      expect(await foreground, isA<Ok<Null, RecoverBullFailure>>());
      expect(state.account, 'second@example.invalid');
    },
  );

  test(
    'discovery session cannot be reused after its callback returns',
    () async {
      final state = _DriveState();
      final repository = _repository(state);
      late GoogleDriveDiscoverySession saved;
      await repository.withDiscoverySession(
        (session) async => saved = session!,
      );
      await expectLater(saved.fetchRawFile('late'), throwsA(isA<Exception>()));
      expect(state.operations, isEmpty);
    },
  );

  test('programmer errors propagate and leave the queue usable', () async {
    final state = _DriveState();
    state.download = (_) async => throw StateError('programmer bug');
    final repository = _repository(state);
    await expectLater(repository.fetchRawFile('bad'), throwsStateError);
    expect(await repository.trash('next'), isA<Ok<Null, RecoverBullFailure>>());
  });

  test('infra exceptions return failures and leave the queue usable', () async {
    final state = _DriveState();
    state.download = (_) async => throw const FormatException('invalid bytes');
    final repository = _repository(state);
    expect(
      await repository.fetchRawFile('bad'),
      isA<Err<String, RecoverBullFailure>>(),
    );
    expect(await repository.trash('next'), isA<Ok<Null, RecoverBullFailure>>());
  });
}

GoogleDriveRepositoryImpl _repository(_DriveState state) =>
    GoogleDriveRepositoryImpl(
      log: const _Log(),
      datasource: _Datasource(state),
    );

DriveFileMetadataModel _file(String id) => DriveFileMetadataModel(
  id: id,
  name: '$id.json',
  createdTime: DateTime.utc(2026),
);

final class _DriveState {
  String? account = 'first@example.invalid';
  String nextInteractiveAccount = 'first@example.invalid';
  int interactiveSignIns = 0;
  int signOuts = 0;
  final operations = <String>[];
  Future<GoogleDriveMetadataPage> Function(String?) listPage = (_) async =>
      const GoogleDriveMetadataPage(files: []);
  Future<List<int>> Function(String)? download;
}

final class _Datasource extends GoogleDriveAppDatasource {
  final _DriveState state;

  _Datasource(this.state)
    : super(log: const _Log(), pageLister: state.listPage);

  @override
  Future<String?> connectSilently() async => state.account;

  @override
  Future<void> connect() async {
    state.interactiveSignIns++;
    state.account = state.nextInteractiveAccount;
  }

  @override
  Future<void> disconnect() async {
    state.signOuts++;
    state.account = null;
  }

  @override
  Future<List<int>> fetchFileContent(String id) async {
    if (state.download case final download?) return download(id);
    state.operations.add('download:$id');
    return utf8.encode(id);
  }

  @override
  Future<void> trash(String id) async => state.operations.add('trash:$id');
}

final class _Log implements LogSink {
  const _Log();

  @override
  void fine(String message, {Object? error, StackTrace? trace}) {}
  @override
  void error(String message, {Object? error, StackTrace? trace}) {}
  @override
  void info(String message, {Object? error, StackTrace? trace}) {}
  @override
  void warning(String message, {Object? error, StackTrace? trace}) {}
  @override
  LogSink scoped(String scope) => this;
}
