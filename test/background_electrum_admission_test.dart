import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/background_bootstrap.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final issue in [
    'missing source',
    'wrong source schema',
    'missing Electrum owner',
  ]) {
    test('wallet dispatcher retries with $issue', () async {
      final directory = await Directory.systemTemp.createTemp(
        'background-electrum-',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      addTearDown(() async {
        await log.flush();
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });
      final source = File('${directory.path}/bullbitcoin_sqlite.sqlite');
      final coordination = Directory('${directory.path}/storage-coordination');
      final legacy = LegacySourceStore(
        source: LegacySource(source, SqliteDatabase.currentSchemaVersion),
        create: SqliteDatabase.new,
      );
      final first = await StorageCutover(
        directory: coordination,
        legacy: legacy,
        expectedOwners: splitV1Owners,
        participants: const [],
      ).prepare();
      expect(first, isA<Ok>());
      if (first case Ok(:final value)) await value.close();
      if (issue == 'missing source') {
        await source.delete();
      } else if (issue == 'wrong source schema') {
        final database = sqlite3.open(source.path);
        try {
          database.userVersion = SqliteDatabase.currentSchemaVersion - 1;
        } finally {
          database.close();
        }
      }

      const task = BackgroundTask.walletsSync;
      var hasRetryHandler = false;
      final acknowledged = await mapBackgroundTaskResult(task.name, (
        task,
      ) async {
        final runner = await bootstrapAdmittedBackgroundRunner(
          task,
          clock: Stopwatch()..start(),
        );
        hasRetryHandler = runner.handlers.containsKey(task);
        return runner;
      });
      expect(hasRetryHandler, isTrue);
      expect(acknowledged, isFalse);
      expect(
        File('${directory.path}/databases/electrum.sqlite').existsSync(),
        isFalse,
      );

      final exclusive = await NativeFileGate(
        File('${coordination.path}/lifecycle.lock'),
      ).acquire(exclusive: true, timeout: Duration.zero);
      await exclusive.close();
    });
  }
}

final class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);

  @override
  Future<String> getApplicationDocumentsPath() async => path;

  @override
  Future<String> getApplicationSupportPath() async => path;
}
