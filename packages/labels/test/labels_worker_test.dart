import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/src/data/labels_import.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:labels/src/data/labels_store.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'owner worker closes its native executor before releasing admission',
    () async {
      final directory = await Directory.systemTemp.createTemp('labels-worker-');
      final gate = NativeFileGate(File('${directory.path}/gate'));
      final admission = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      );
      final opened = await LabelsStore.open(
        File('${directory.path}/db'),
        admission,
        existing: false,
        testingWorker: _spawnFixture,
      );
      expect(opened, isA<Ok>());
      final store = (opened as Ok<LabelsStore, DatabaseOpenFailure>).value;
      await store.database.customStatement(
        "INSERT INTO frozen_utxos VALUES ('origin', 'tx', 0)",
      );
      await store.database.customStatement('DROP TABLE legacy_import_receipts');
      expect(
        await readLabelsReadiness(store.database),
        isA<Err<OwnerReadiness, LegacyImportFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<LegacyImportUnavailable>(),
        ),
      );
      await admission.close();
      final next = await gate.acquire(exclusive: true, timeout: Duration.zero);
      await next.close();
      await directory.delete(recursive: true);
    },
  );

  test('Labels keeps the lease when native closure is unconfirmed', () async {
    final directory = await Directory.systemTemp.createTemp('labels-worker-');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final admission = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    );
    final intercepted = ReceivePort();
    final nativeClosed = intercepted.first;
    final acknowledgements = <SendPort>[];
    addTearDown(() async {
      for (final port in acknowledgements) {
        port.send(true);
      }
      intercepted.close();
      await admission.close();
      await directory.delete(recursive: true);
    });

    final opened = await LabelsStore.open(
      File('${directory.path}/db'),
      admission,
      existing: false,
      testingWorker: (path, existing, status, closed) {
        acknowledgements.add(closed);
        return _spawnFixture(path, existing, status, intercepted.sendPort);
      },
    );
    expect(opened, isA<Ok>());

    await expectLater(admission.close(), throwsA(isA<LifecycleException>()));
    expect(await nativeClosed, isTrue);
    await expectLater(
      gate.acquire(exclusive: true, timeout: Duration.zero),
      throwsA(isA<LifecycleException>()),
    );

    acknowledgements.single.send(true);
    await LifecycleAdmission.retryQuarantined();
    final next = await gate.acquire(exclusive: true, timeout: Duration.zero);
    await next.close();
  });
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
