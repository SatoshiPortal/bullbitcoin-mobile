import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show RootIsolateToken;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:mempool/src/data/mempool_store.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real Mempool worker defers when the owner file is absent', () async {
    expect(RootIsolateToken.instance, isNotNull);
    final directory = await Directory.systemTemp.createTemp('mempool-worker-');
    addTearDown(() => directory.delete(recursive: true));
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final file = File('${directory.path}/db');
    final admission = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    );

    final opened = await MempoolStore.open(
      file,
      admission,
      existing: true,
    ).timeout(const Duration(seconds: 2));
    await admission.close();
    expect(
      opened,
      isA<Err<MempoolStore, DatabaseOpenFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<DatabaseNotReady>(),
      ),
    );
    expect(file.existsSync(), isFalse);
    final next = await gate.acquire(exclusive: true, timeout: Duration.zero);
    await next.close();
  });

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
