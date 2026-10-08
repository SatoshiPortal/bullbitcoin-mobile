import 'package:flutter_test/flutter_test.dart';
import 'package:bull_recoverbull/src/data/datasources/google_drive_datasource.dart';
import 'package:bull_recoverbull/src/data/models/drive_file_metadata_model.dart';
import 'package:bull_recoverbull/src/data/debug_google_drive_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

void main() {
  test(
    'production listing contract requests pagination fields and page size',
    () {
      expect(
        GoogleDriveAppDatasource.metadataFields,
        contains('nextPageToken'),
      );
      expect(GoogleDriveAppDatasource.metadataPageSize, 1000);
    },
  );

  test('metadata listing follows pages and rejects a repeated token', () async {
    final pages = <String?, GoogleDriveMetadataPage>{
      null: GoogleDriveMetadataPage(
        files: [_file('one')],
        nextPageToken: 'second',
      ),
      'second': GoogleDriveMetadataPage(
        files: [_file('two')],
        nextPageToken: 'final',
      ),
      'final': GoogleDriveMetadataPage(files: [_file('three')]),
    };
    final datasource = GoogleDriveAppDatasource(
      log: _Log(),
      pageLister: (token) async => pages[token]!,
    );
    expect(await datasource.fetchAllMetadata(), hasLength(3));
    expect(
      (await datasource.fetchAllMetadata()).map((file) => file.id),
      orderedEquals(['one', 'two', 'three']),
    );

    final repeated = GoogleDriveAppDatasource(
      log: _Log(),
      pageLister: (token) async => GoogleDriveMetadataPage(
        files: [_file('page')],
        nextPageToken: 'same',
      ),
    );
    await expectLater(repeated.fetchAllMetadata(), throwsStateError);
  });

  test(
    'debug selection has an explicit release guard and fake operations',
    () async {
      final production = DebugGoogleDriveRepository();
      expect(
        () => selectGoogleDriveRepository(
          production: production,
          fakeEnabled: true,
          debugMode: false,
        ),
        throwsStateError,
      );
      final fake = selectGoogleDriveRepository(
        production: production,
        fakeEnabled: true,
        debugMode: true,
      );
      await fake.connect();
      final files = switch (await fake.fetchAllMetadata()) {
        Ok(:final value) => value,
        Err() => throw StateError('fake metadata failed'),
      };
      expect(files, hasLength(3));
      expect(files.map((file) => file.createdTime.year), everyElement(2026));
      final firstId = files.first.id;
      expect(await fake.fetchVault(firstId), isA<Ok>());
      final firstContent = switch (await fake.fetchRawFile(firstId)) {
        Ok(:final value) => value,
        Err() => throw StateError('fake content failed'),
      };
      expect(await fake.fetchLatestVault(), isA<Ok>());
      expect(await fake.store(firstContent), isA<Ok>());
      final afterStore = await fake.fetchAllMetadata();
      expect(switch (afterStore) {
        Ok(:final value) => value.length,
        Err() => -1,
      }, 4);
      expect(await fake.trash(firstId), isA<Ok>());
      final afterTrash = await fake.fetchAllMetadata();
      expect(switch (afterTrash) {
        Ok(:final value) => value.length,
        Err() => -1,
      }, 3);
      expect(await fake.fetchRawFile(firstId), isA<Err>());
      expect(await fake.trash('missing'), isA<Err>());
      await fake.disconnect();
      expect(await fake.fetchAllMetadata(), isA<Err>());
      expect(await fake.fetchLatestVault(), isA<Err>());
      expect(await fake.store(firstContent), isA<Err>());
      expect(await fake.trash(files.last.id), isA<Err>());
      expect(await fake.connectSilently(), 'recoverbull.debug@example.invalid');
      expect(await fake.fetchAllMetadata(), isA<Ok>());
    },
  );

  test(
    'debug discovery session serializes disconnect until the action completes',
    () async {
      final fake = DebugGoogleDriveRepository();
      Future<void>? pendingDisconnect;
      Future<dynamic>? pendingRead;
      var readCompleted = false;
      var disconnectCompleted = false;
      final sessionDone = fake.withDiscoverySession((session) async {
        expect(session, isNotNull);
        pendingDisconnect = fake.disconnect();
        pendingRead = fake.fetchAllMetadata();
        pendingDisconnect!.whenComplete(() => disconnectCompleted = true);
        pendingRead!.whenComplete(() => readCompleted = true);
        expect(disconnectCompleted, isFalse);
        expect(readCompleted, isFalse);
        return null;
      });
      await sessionDone;
      await pendingDisconnect;
      await pendingRead;
      expect(disconnectCompleted, isTrue);
      expect(readCompleted, isTrue);
      await fake.disconnect();
    },
  );

  test('debug discovery queue continues after a thrown callback', () async {
    final fake = DebugGoogleDriveRepository();
    await expectLater(
      fake.withDiscoverySession<void>((_) async => throw StateError('test')),
      throwsStateError,
    );
    expect(await fake.connect(), isA<Ok>());
  });
}

DriveFileMetadataModel _file(String id) => DriveFileMetadataModel(
  id: id,
  name: '$id.json',
  createdTime: DateTime.utc(2026),
);

final class _Log implements LogSink {
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
