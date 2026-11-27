import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/data/backup_guard.dart';
import 'package:secrets/src/data/secrets_database.dart';

void main() {
  test('drain waits for an admitted guarded transaction', () async {
    final database = SecretsDatabase(NativeDatabase.memory());
    final entered = Completer<void>();
    final release = Completer<void>();
    final transaction = guardedTransaction(database, () async {
      await database.customStatement(
        'CREATE TABLE IF NOT EXISTS drain_test (v INTEGER)',
      );
      await database.customStatement('INSERT INTO drain_test VALUES (1)');
      entered.complete();
      await release.future;
    });
    await entered.future;
    var drained = false;
    final drain = inventoryWritesSettled().then((_) => drained = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final drainedBeforeRelease = drained;
    release.complete();
    await transaction;
    await drain;
    await database.close();
    expect(drainedBeforeRelease, isFalse);
  });
}
