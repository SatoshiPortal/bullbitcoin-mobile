import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/src/data/inventory_store.dart';
import 'package:secrets/testing.dart';

/// A fresh admitted inventory file for the view tests. [close] releases it.
final class ViewFixture {
  final Directory directory;
  final File file;
  final RuntimeAdmission admission;

  ViewFixture._(this.directory, this.file, this.admission);

  static Future<ViewFixture> create() async {
    final directory = await Directory.systemTemp.createTemp('views-');
    FakeSecureStoragePlatform().install();
    final file = File('${directory.path}/secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final participant = SecretsImport(file: file);
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final result = await participant.prepare(exclusive, OwnerOrigin.fresh);
      final owner = (result as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await exclusive.close();
    }
    final admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    return ViewFixture._(directory, file, admission);
  }

  /// Runs raw SQL on the file the way a build that supports more views would
  /// have left it.
  Future<void> sql(List<String> statements) async {
    final opened = await InventoryStore.open(file, admission, existing: true);
    final store = (opened as Ok<InventoryStore, Failure>).value;
    try {
      for (final statement in statements) {
        await store.database.customStatement(statement);
      }
    } finally {
      await store.close();
    }
  }

  Future<void> close() async {
    await admission.close();
    await directory.delete(recursive: true);
  }
}
