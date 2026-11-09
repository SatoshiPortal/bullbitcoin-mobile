import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/adapters/labels_repository_adapter.dart';
import 'package:bb_mobile/features/labels/application/store_label_application.dart';
import 'package:bb_mobile/features/labels/application/usecases/store_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reporter implements LoggerReporter {
  final arguments = <String>[];
  var errors = 0;

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) {
    errors++;
    arguments.addAll([
      message ?? '',
      exception.toString(),
      stackTrace.toString(),
      category.name,
    ]);
  }

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async {}
}

void main() {
  test(
    'post-broadcast label write failure keeps txid out of diagnostics',
    () async {
      final database = SqliteDatabase(NativeDatabase.memory());
      final directory = await Directory.systemTemp.createTemp('sendlog-label-');
      final reporter = _Reporter();
      addTearDown(() async {
        await database.close();
        await log.flush();
        log = Logger.replace(directory: Directory.current);
        await directory.delete(recursive: true);
      });
      // Initialize normally before making subsequent writes fail in real SQLite.
      await database.select(database.labels).get();
      await database.customStatement('PRAGMA query_only = ON');
      // Confirm SQLite's real write refusal independently of the logger.
      await expectLater(
        database.customStatement('CREATE TABLE privacy_probe (id INTEGER)'),
        throwsA(
          isA<SqliteException>().having((e) => e.resultCode, 'read-only', 8),
        ),
      );
      log = Logger.replace(directory: directory, reporter: reporter);
      final usecase = StoreLabelUsecase(
        labelRepository: DriftLabelsRepositoryAdapter(database: database),
      );
      const txid =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      // SendCubit stores the final txid and user label here after a successful
      // ordinary broadcast, and after terminal Payjoin completion/fallback.
      final result = await usecase.execute(
        const NewApplicationLabel(
          type: LabelType.transaction,
          label: 'sendlog-review-label',
          reference: txid,
          origin: 'review-wallet',
        ),
      );
      await log.flush();
      expect(result, isA<Err>());
      expect(
        (result as Err).failure.logMessage,
        'label_store_failed category=unexpected',
      );
      expect(reporter.errors, 1);
      final disk = await log.logsFile.readAsString();
      final diagnostics = '$disk\n${reporter.arguments.join('\n')}';
      for (final sentinel in [
        txid,
        'sendlog-review-label',
        'review-wallet',
        'INSERT',
        'SqliteException',
      ]) {
        expect(diagnostics, isNot(contains(sentinel)));
      }
      expect(disk, contains('SEVERE'));
      expect(disk, contains('label_store_failed category=unexpected'));
      expect(reporter.arguments[0], 'label_store_failed category=unexpected');
      expect(
        reporter.arguments[1],
        'Exception: label_store_failed category=unexpected',
      );
      expect(reporter.arguments[3], 'error');
    },
  );
}
