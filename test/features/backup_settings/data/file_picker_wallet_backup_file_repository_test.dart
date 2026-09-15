import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/features/backup_settings/data/file_picker_wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockFilePicker extends Mock implements FilePicker {}

void main() {
  late _MockFilePicker picker;
  late FilePickerWalletBackupFileRepository repository;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    picker = _MockFilePicker();
    repository = FilePickerWalletBackupFileRepository(picker);
  });

  test('picker cancellation is not an error', () async {
    when(
      () => picker.pickFiles(type: FileType.any),
    ).thenAnswer((_) async => null);

    expect(
      await repository.pick(maximumBytes: 10),
      isA<Ok<Uint8List?, BackupSettingsFailure>>().having(
        (result) => result.value,
        'value',
        isNull,
      ),
    );
  });

  test('rejects the declared size before reading file bytes', () async {
    when(() => picker.pickFiles(type: FileType.any)).thenAnswer(
      (_) async =>
          FilePickerResult([PlatformFile(name: 'large.json.enc', size: 11)]),
    );

    expect(
      await repository.pick(maximumBytes: 10),
      isA<Err<Uint8List?, BackupSettingsFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<BackupSettingsFileTooLargeFailure>(),
      ),
    );
  });

  test(
    'rejects oversized in-memory bytes despite a smaller declared size',
    () async {
      when(() => picker.pickFiles(type: FileType.any)).thenAnswer(
        (_) async => FilePickerResult([
          PlatformFile(
            name: 'large.json.enc',
            size: 10,
            bytes: Uint8List.fromList(List.filled(11, 1)),
          ),
        ]),
      );

      expect(
        await repository.pick(maximumBytes: 10),
        isA<Err<Uint8List?, BackupSettingsFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<BackupSettingsFileTooLargeFailure>(),
        ),
      );
    },
  );

  test('caps path reads and rejects an oversized changed file', () async {
    final temporary = await Directory.systemTemp.createTemp('backup-read-');
    addTearDown(() => temporary.delete(recursive: true));
    final file = File('${temporary.path}/backup.json.enc');
    await file.writeAsBytes(List.filled(11, 1));
    when(() => picker.pickFiles(type: FileType.any)).thenAnswer(
      (_) async => FilePickerResult([
        PlatformFile(name: file.path, path: file.path, size: 10),
      ]),
    );

    expect(
      await repository.pick(maximumBytes: 10),
      isA<Err<Uint8List?, BackupSettingsFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<BackupSettingsFileTooLargeFailure>(),
      ),
    );
  });

  test('rejects in-memory bytes that do not match the declared size', () async {
    when(() => picker.pickFiles(type: FileType.any)).thenAnswer(
      (_) async => FilePickerResult([
        PlatformFile(
          name: 'backup.json.enc',
          size: 3,
          bytes: Uint8List.fromList([1, 2]),
        ),
      ]),
    );

    expect(
      await repository.pick(maximumBytes: 10),
      isA<Err<Uint8List?, BackupSettingsFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<BackupSettingsFileReadFailure>(),
      ),
    );
  });

  test('saves the exact bytes with the suggested filename', () async {
    final export = WalletBackupExport(
      suggestedFilename: 'backup.json.enc',
      bytes: const [1, 2, 3],
    );
    when(
      () => picker.saveFile(
        bytes: any(named: 'bytes'),
        fileName: 'backup.json.enc',
      ),
    ).thenAnswer((_) async => '/saved/backup.json.enc');

    expect(
      await repository.save(export),
      isA<Ok<bool, BackupSettingsFailure>>().having(
        (result) => result.value,
        'value',
        isTrue,
      ),
    );
    final captured =
        verify(
              () => picker.saveFile(
                bytes: captureAny(named: 'bytes'),
                fileName: 'backup.json.enc',
              ),
            ).captured.single
            as Uint8List;
    expect(captured, orderedEquals([1, 2, 3]));
  });

  test('save cancellation is a neutral false result', () async {
    final export = WalletBackupExport(
      suggestedFilename: 'backup.json.enc',
      bytes: const [1, 2, 3],
    );
    when(
      () => picker.saveFile(
        bytes: any(named: 'bytes'),
        fileName: 'backup.json.enc',
      ),
    ).thenAnswer((_) async => null);

    expect(
      await repository.save(export),
      isA<Ok<bool, BackupSettingsFailure>>().having(
        (result) => result.value,
        'value',
        isFalse,
      ),
    );
  });
}
