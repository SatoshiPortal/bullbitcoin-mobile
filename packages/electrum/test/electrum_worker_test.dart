import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:electrum/src/data/electrum_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:electrum/src/data/electrum_store.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'owner worker closes its native executor before releasing admission',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'electrum-worker-',
      );
      final gate = NativeFileGate(File('${directory.path}/gate'));
      final admission = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      );
      final opened = await ElectrumStore.open(
        File('${directory.path}/db'),
        admission,
        existing: false,
        testingWorker: _spawnFixture,
      );
      expect(opened, isA<Ok>());
      final store = (opened as Ok<ElectrumStore, DatabaseOpenFailure>).value;
      await store.database.customStatement(
        "INSERT INTO electrum_settings VALUES ('test', 0, 20, 5, 5, NULL)",
      );
      await store.database.customStatement('DROP TABLE legacy_import_receipts');
      expect(
        await readElectrumReadiness(store.database),
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

  test('Electrum keeps the lease when native closure is unconfirmed', () async {
    final directory = await Directory.systemTemp.createTemp('electrum-worker-');
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

    final opened = await ElectrumStore.open(
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
