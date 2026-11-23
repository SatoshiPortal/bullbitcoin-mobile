import 'dart:io';

import 'package:backup_metadata/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';

class _Paths extends PathProviderPlatform {
  final String _documents;

  _Paths(this._documents);

  @override
  Future<String?> getApplicationDocumentsPath() async => _documents;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'metadata backup requires storage admission and a migrated app database',
    () async {
      final documents = await Directory.systemTemp.createTemp('backup-ready');
      addTearDown(() => documents.delete(recursive: true));
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(documents.path);
      addTearDown(() => PathProviderPlatform.instance = previousPaths);

      var admitted = false;
      var schemaQueries = 0;
      final readiness = MetadataBackupReadiness(
        hasStorageAdmission: () => admitted,
        isAtCurrentSchema: () {
          schemaQueries++;
          return SqliteDatabase.isAtCurrentSchema();
        },
      );
      final path = '${documents.path}/${SqliteDatabase.name}.sqlite';
      expect(await readiness.databaseReady(), isFalse);
      expect(schemaQueries, 0);
      admitted = true;
      expect(await readiness.databaseReady(), isFalse);
      expect(File(path).existsSync(), isFalse);

      final database = sqlite3.open(path);
      addTearDown(database.close);
      final current = SqliteDatabase.currentSchemaVersion;
      database.userVersion = current - 1;
      expect(await readiness.databaseReady(), isFalse);
      expect(database.userVersion, current - 1);
      database.userVersion = current;
      expect(await readiness.databaseReady(), isTrue);
    },
  );
}
