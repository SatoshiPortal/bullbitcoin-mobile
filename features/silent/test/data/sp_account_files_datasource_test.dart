import 'dart:io';

import 'package:silent/src/data/datasources/sp_account_files_datasource.dart';
import 'package:silent/src/data/sp_storage_names.dart';
import 'package:flutter_test/flutter_test.dart';

// The pending-scan marker is the only state the account directory keeps outside
// bwk, and a restart reads it back before any UI exists. These tests pin its
// on-disk shape and the atomic replacement.
void main() {
  late Directory tempDir;
  late SpAccountFilesDatasource files;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sp_files_test_');
    Directory('${tempDir.path}/${SpStorageNames.accountName}')
        .createSync(recursive: true);
    files = SpAccountFilesDatasource();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File markerFile() => File(
    '${tempDir.path}/${SpStorageNames.accountName}/'
    '${SpStorageNames.pendingScanFile}',
  );

  test('a written marker reads back unchanged', () async {
    await files.writePendingScan(tempDir.path, (
      startHeight: 975000,
      isPaused: false,
    ));

    expect(await files.readPendingScan(tempDir.path), (
      startHeight: 975000,
      isPaused: false,
    ));
  });

  test('a paused marker keeps its start height', () async {
    await files.writePendingScan(tempDir.path, (
      startHeight: 975000,
      isPaused: true,
    ));

    expect(await files.readPendingScan(tempDir.path), (
      startHeight: 975000,
      isPaused: true,
    ));
  });

  test('a marker without a start height is valid', () async {
    await files.writePendingScan(tempDir.path, (
      startHeight: null,
      isPaused: false,
    ));

    expect(await files.readPendingScan(tempDir.path), (
      startHeight: null,
      isPaused: false,
    ));
  });

  test('no marker on disk reads as absent', () async {
    expect(await files.readPendingScan(tempDir.path), isNull);
  });

  test('an unreadable marker is not treated as absent', () async {
    await Directory(markerFile().path).create();
    await expectLater(
      files.readPendingScan(tempDir.path),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('writing null deletes the marker', () async {
    await files.writePendingScan(tempDir.path, (
      startHeight: 975000,
      isPaused: false,
    ));

    await files.writePendingScan(tempDir.path, null);

    expect(markerFile().existsSync(), isFalse);
    expect(await files.readPendingScan(tempDir.path), isNull);
  });

  test('the replacement leaves no temp file behind', () async {
    await files.writePendingScan(tempDir.path, (
      startHeight: 900000,
      isPaused: true,
    ));
    await files.writePendingScan(tempDir.path, (
      startHeight: 975000,
      isPaused: false,
    ));

    expect(
      File('${markerFile().path}.tmp').existsSync(),
      isFalse,
      reason: 'the temp file is renamed into place, never kept',
    );
    expect(await files.readPendingScan(tempDir.path), (
      startHeight: 975000,
      isPaused: false,
    ));
  });

  test('unparseable contents raise FormatException', () async {
    await markerFile().writeAsString('not a scan');

    await expectLater(
      files.readPendingScan(tempDir.path),
      throwsA(isA<FormatException>()),
    );
  });

  test('a wrong shape raises FormatException', () async {
    await markerFile().writeAsString('{"startHeight": -1, "isPaused": false}');

    await expectLater(
      files.readPendingScan(tempDir.path),
      throwsA(isA<FormatException>()),
    );
  });

  test('a missing field raises FormatException', () async {
    await markerFile().writeAsString('{"startHeight": 10}');

    await expectLater(
      files.readPendingScan(tempDir.path),
      throwsA(isA<FormatException>()),
    );
  });
}
