import 'dart:io';
import 'package:bull_recoverbull/src/data/datasources/file_storage_datasource.dart';
import 'package:bull_recoverbull/src/data/file_system_repository_impl.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import '../support/log_sink.dart';

class _Files extends Mock implements FileStorageDatasource {}

void main() {
  test(
    'picker failures expose no file content, path, or exception payload',
    () async {
      final files = _Files();
      final log = TestLogSink.recording();
      when(() => files.pickFile()).thenThrow(
        const FileSystemException('private payload', '/private/vault'),
      );
      final repository = FileSystemRepositoryImpl(log: log, datasource: files);
      final result = await repository.pickVault();
      expect(
        (result as Err<EncryptedVault, RecoverBullFailure>).failure,
        isA<RecoverBullUnexpectedFailure>(),
      );
      expect(
        log.entries.single.message,
        'recoverbull.file.pick.unexpected error_type=FileSystemException',
      );
      expect(log.entries.single.error, isNull);
      expect(log.entries.single.message, isNot(contains('/private/vault')));
    },
  );

  test('programmer errors from the picker stay Errors', () async {
    final files = _Files();
    when(() => files.pickFile()).thenThrow(StateError('bug'));
    final repository = FileSystemRepositoryImpl(
      log: const TestLogSink(),
      datasource: files,
    );
    await expectLater(repository.pickVault(), throwsStateError);
  });
}
