import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:mempool/src/data/mempool_store.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'owner worker closes its native executor before releasing admission',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mempool-worker-',
      );
      final gate = NativeFileGate(File('${directory.path}/gate'));
      final admission = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      );
      final opened = await MempoolStore.open(
        File('${directory.path}/db'),
        admission,
        existing: false,
        testingWorker: _spawnFixture,
      );
      expect(opened, isA<Ok>());
      final store = (opened as Ok<MempoolStore, DatabaseOpenFailure>).value;
      await store.database.customStatement(
        "INSERT INTO mempool_settings VALUES ('test', 0)",
      );
      await admission.close();
      final next = await gate.acquire(exclusive: true, timeout: Duration.zero);
      await next.close();
      await directory.delete(recursive: true);
    },
  );
}

Future<DriftIsolate> _spawnFixture(
  String path,
  bool existing,
  SendPort status,
  SendPort closed,
) => DriftIsolate.spawn(() {
  status.send(null);
  return DatabaseConnection(
    NativeDatabase(File(path))
        .interceptWith(NativeCloseAcknowledgement(closed), sticky: false),
  );
});
