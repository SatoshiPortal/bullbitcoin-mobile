import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:preferences/src/data/preferences_store.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'failure before a worker exists is typed and does not strand admission',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'preferences-spawn-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final gate = NativeFileGate(File('${directory.path}/gate'));
      final admission = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      );
      addTearDown(admission.close);
      final opened = await PreferencesStore.open(
        File('${directory.path}/db'),
        admission,
        existing: true,
        testingWorker: (_, _, _, _) async =>
            throw const LifecycleException('fixture_spawn'),
      );
      expect(
        opened,
        isA<Err<PreferencesStore, DatabaseOpenFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<DatabaseFileUnavailable>(),
        ),
      );
      await admission.close();
      final next = await gate.acquire(exclusive: true, timeout: Duration.zero);
      await next.close();
      expect(File('${directory.path}/db').existsSync(), isFalse);
    },
  );

  test(
    'owner worker closes its native executor before releasing admission',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'preferences-worker-',
      );
      final gate = NativeFileGate(File('${directory.path}/gate'));
      final admission = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      );
      final opened = await PreferencesStore.open(
        File('${directory.path}/db'),
        admission,
        existing: false,
        testingWorker: _spawnFixture,
      );
      expect(opened, isA<Ok>());
      final store = (opened as Ok<PreferencesStore, DatabaseOpenFailure>).value;
      await store.database.customStatement(
        'INSERT INTO recoverbull VALUES (1, 0)',
      );
      await admission.close();
      final next = await gate.acquire(exclusive: true, timeout: Duration.zero);
      await next.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'disconnect cannot release admission before native acknowledgement',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'preferences-close-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final gate = NativeFileGate(File('${directory.path}/gate'));
      final admission = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      );
      final nativeClosed = ReceivePort();
      final confirmation = nativeClosed.first;
      SendPort? acknowledgement;
      final opened = await PreferencesStore.open(
        File('${directory.path}/db'),
        admission,
        existing: false,
        testingWorker: (path, existing, status, closed) {
          acknowledgement = closed;
          return _spawnFixture(path, existing, status, nativeClosed.sendPort);
        },
      );
      expect(opened, isA<Ok>());
      final acknowledge = acknowledgement;
      if (acknowledge == null) fail('Missing acknowledgement port');
      addTearDown(() async {
        await admission.close();
        nativeClosed.close();
      });
      await expectLater(
        admission.close(),
        throwsA(
          isA<LifecycleException>().having(
            (error) => error.reason,
            'reason',
            'resources_still_open',
          ),
        ),
      );
      await confirmation;
      try {
        await expectLater(
          gate.acquire(exclusive: true, timeout: Duration.zero),
          throwsA(isA<LifecycleException>()),
        );
      } finally {
        acknowledge.send(null);
      }
      await LifecycleAdmission.retryQuarantined();
      final next = await gate.acquire(exclusive: true, timeout: Duration.zero);
      await next.close();
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
