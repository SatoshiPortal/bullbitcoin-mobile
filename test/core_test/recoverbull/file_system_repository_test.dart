import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/recoverbull/data/datasources/file_storage_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileStorage extends Fake implements FileStorageDatasource {
  final File? file;
  final Exception? exception;

  _FileStorage({this.file, this.exception});

  @override
  Future<File?> pickFile({List<String>? extensions}) async {
    if (exception case final error?) throw error;
    return file;
  }
}

class _InvalidFile extends Fake implements File {
  @override
  Future<String> readAsString({Encoding encoding = utf8}) async => '{}';
}

void main() {
  test('picker cancellation is distinct from a failed file read', () async {
    final repository = FileSystemRepository(datasource: _FileStorage());

    final result = await repository.pickVault();

    expect(
      result,
      isA<Err>().having(
        (value) => value.failure,
        'failure',
        isA<VaultSelectionCancelledFailure>(),
      ),
    );
  });

  test('an invalid selected file still reports a validation failure', () async {
    final repository = FileSystemRepository(
      datasource: _FileStorage(file: _InvalidFile()),
    );

    final result = await repository.pickVault();

    expect(
      result,
      isA<Err>().having(
        (value) => value.failure,
        'failure',
        isA<InvalidVaultFileFailure>(),
      ),
    );
  });

  test(
    'foreign picker errors cannot expose their payload in logs or failure',
    () async {
      const secret = 'synthetic-private-file-error';
      final originalDirectory = log.dir;
      final directory = Directory.systemTemp.createTempSync(
        'bbm_file_error_log_',
      );
      final logger = Logger.replace(directory: directory);
      log = logger;
      addTearDown(() async {
        await logger.flush();
        log = Logger.replace(directory: originalDirectory);
        await directory.delete(recursive: true);
      });
      await logger.ensureLogsExist();
      final repository = FileSystemRepository(
        datasource: _FileStorage(exception: const FormatException(secret)),
      );

      final result = await repository.pickVault();

      expect(
        result,
        isA<Err>().having(
          (value) => value.failure,
          'failure',
          isA<RecoverBullUnexpectedCoreFailure>().having(
            (failure) => failure.logMessage,
            'logMessage',
            isNull,
          ),
        ),
      );
      await logger.flush();
      final recorded = await logger.logsFile.readAsString();
      expect(recorded, contains('FormatException'));
      expect(recorded, isNot(contains(secret)));
    },
  );
}
