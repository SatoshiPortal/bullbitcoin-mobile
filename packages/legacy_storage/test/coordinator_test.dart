import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'support/dart_executable.dart';
import 'support/coordinator_fixture.dart';

void main() {
  late Directory directory;
  setUp(
    () async => directory = await Directory.systemTemp.createTemp('cutover-'),
  );
  tearDown(() => directory.delete(recursive: true));

  Future<RuntimeAdmission> prepare({bool later = false}) async {
    final result = await fixtureCutover(directory, later: later).prepare();
    expect(result, isA<Ok<RuntimeAdmission, LegacyImportFailure>>());
    return (result as Ok<RuntimeAdmission, LegacyImportFailure>).value;
  }

  test(
    'fresh pilot preserves later owner legacy writes across its future import',
    () async {
      final first = await prepare();
      final source = FixtureDatabase(
        File('${directory.path}/legacy.sqlite'),
        legacy: true,
      );
      final handle = first.track(source.close);
      await source.customStatement(
        "INSERT INTO sample VALUES (7, 'exact legacy state')",
      );
      await handle.close();
      await first.close();
      for (var attempt = 0; attempt < 2; attempt++) {
        final runtime = await prepare(later: true);
        final later = FixtureDatabase(File('${directory.path}/later.sqlite'));
        final owned = runtime.track(later.close);
        final rows = await later.customSelect('SELECT * FROM sample').get();
        expect(rows.single.data, {'id': 7, 'data': 'exact legacy state'});
        expect(
          await hasLegacyImportReceipt(later, 'split-v1/later'),
          isA<Ok<bool, LegacyImportFailure>>().having(
            (v) => v.value,
            'receipt',
            true,
          ),
        );
        expect(
          await hasLegacyImportReceipt(later, 'fresh-v1/later'),
          isA<Ok<bool, LegacyImportFailure>>().having(
            (v) => v.value,
            'receipt',
            false,
          ),
        );
        await owned.close();
        await runtime.close();
      }
    },
  );

  test(
    'committed destination mutations survive repeated preparation',
    () async {
      final first = await prepare();
      final db = FixtureDatabase(File('${directory.path}/pilot.sqlite'));
      final handle = first.track(db.close);
      await db.customStatement("UPDATE sample SET data = 'changed'");
      await handle.close();
      await first.close();
      for (var i = 0; i < 2; i++) {
        final runtime = await prepare();
        final check = FixtureDatabase(File('${directory.path}/pilot.sqlite'));
        final owned = runtime.track(check.close);
        expect(
          (await check.customSelect('SELECT data FROM sample').getSingle())
              .read<String>('data'),
          'changed',
        );
        await owned.close();
        await runtime.close();
      }
    },
  );

  test(
    'an admitted owner cannot be recreated from stale legacy data',
    () async {
      final source = File('${directory.path}/legacy.sqlite');
      final legacy = FixtureDatabase(source, legacy: true);
      await legacy.customStatement(
        "INSERT INTO sample VALUES (1, 'stale legacy data')",
      );
      await legacy.close();
      await (await prepare()).close();
      final file = File('${directory.path}/pilot.sqlite');
      final database = FixtureDatabase(file);
      await database.customStatement(
        "UPDATE sample SET data = 'live owner data'",
      );
      await database.close();
      final before = await source.readAsBytes();
      await file.delete();

      final foreground = await fixtureCutover(directory).prepare();
      if (foreground case Ok(:final value)) await value.close();
      expect(
        foreground,
        isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
          (result) => result.failure,
          'admission after owner loss',
          isA<LegacyImportUnavailable>(),
        ),
      );
      expect(file.existsSync(), isFalse);
      expect(await source.readAsBytes(), before);
      final background = await fixtureCutover(directory).admit();
      expect(
        background,
        isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
          (result) => result.failure,
          'headless admission after owner loss',
          isA<LegacyImportUnavailable>(),
        ),
      );
    },
  );

  test(
    'established missing source and orphan sidecars never create a source',
    () async {
      await (await prepare()).close();
      await File('${directory.path}/legacy.sqlite').delete();
      expect(await fixtureCutover(directory).prepare(), isA<Err>());
      expect(File('${directory.path}/legacy.sqlite').existsSync(), isFalse);
    },
  );

  test(
    'foreground can prepare while a background isolate is admitted',
    () async {
      final background = await prepare();
      final path = directory.path;
      try {
        final (ready, pending) = await Isolate.run(() async {
          final directory = Directory(path);
          final foreground = await fixtureCutover(directory)
              .prepare(timeout: Duration.zero);
          if (foreground case Ok(:final value)) await value.close();
          final later = await fixtureCutover(
            directory,
            later: true,
          ).prepare(timeout: Duration.zero);
          if (later case Ok(:final value)) await value.close();
          return (
            foreground is Ok<RuntimeAdmission, LegacyImportFailure>,
            later is Err<RuntimeAdmission, LegacyImportFailure>,
          );
        });
        expect(ready, isTrue);
        expect(pending, isTrue);
      } finally {
        await background.close();
      }
    },
  );

  test(
    'first verified receipt can be resumed before owner admission',
    () async {
      final interrupted = await fixtureCutover(
        directory,
        durableStep: (step) async {
          if (step == 'owner-pilot') {
            throw const FileSystemException('fixture interruption');
          }
        },
      ).prepare();
      expect(interrupted, isA<Err<RuntimeAdmission, LegacyImportFailure>>());
      expect(File('${directory.path}/pilot.sqlite').existsSync(), isTrue);
      final notYetAdmitted = await fixtureCutover(directory).admit();
      if (notYetAdmitted case Ok(:final value)) await value.close();
      expect(
        notYetAdmitted,
        isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
          (result) => result.failure,
          'background requires published milestone',
          isA<LegacyImportDeferred>(),
        ),
      );
      await (await prepare()).close();
      final admitted = await fixtureCutover(directory).admit();
      expect(admitted, isA<Ok<RuntimeAdmission, LegacyImportFailure>>());
      if (admitted case Ok(:final value)) await value.close();
    },
  );

  test('new source with orphan WAL is not interpreted as fresh', () async {
    await File('${directory.path}/legacy.sqlite-wal').writeAsString('orphan');
    expect(await fixtureCutover(directory).prepare(), isA<Err>());
    expect(File('${directory.path}/legacy.sqlite').existsSync(), isFalse);
  });

  group('source provenance', () {
    StorageCutover cutoverWith(List<LegacyImportParticipant> participants) {
      final fixture = fixtureCutover(directory);
      return StorageCutover(
        directory: fixture.directory,
        legacy: fixture.legacy,
        expectedOwners: fixture.expectedOwners,
        participants: participants,
      );
    }

    test('a refusal precedes the first marker and creates nothing', () async {
      final owner = ProvenanceOwner(
        'pilot',
        File('${directory.path}/pilot.sqlite'),
        verdict: const Err(LegacyImportVerificationFailed()),
      );
      final result = await cutoverWith([owner]).prepare();
      expect(
        result,
        isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<LegacyImportVerificationFailed>(),
        ),
      );
      expect(owner.asked, [false]);
      expect(
        File('${directory.path}/coordination/split-v1.json').existsSync(),
        isFalse,
      );
      expect(File('${directory.path}/legacy.sqlite').existsSync(), isFalse);
      expect(File('${directory.path}/pilot.sqlite').existsSync(), isFalse);
    });

    test('an existing legacy database is reported as present', () async {
      final legacy = FixtureDatabase(
        File('${directory.path}/legacy.sqlite'),
        legacy: true,
      );
      await legacy.customStatement('SELECT 1');
      await legacy.close();
      final owner = ProvenanceOwner(
        'pilot',
        File('${directory.path}/pilot.sqlite'),
      );
      await (await cutoverWith([owner]).prepare()
              as Ok<RuntimeAdmission, LegacyImportFailure>)
          .value
          .close();
      expect(owner.asked, [true, true]);
    });

    test(
      'a marker published before the owner joined is checked before its import',
      () async {
        await (await prepare()).close();
        final marker = File('${directory.path}/coordination/split-v1.json');
        final before = await marker.readAsString();
        final later = ProvenanceOwner(
          'later',
          File('${directory.path}/later.sqlite'),
          verdict: const Err(LegacyImportVerificationFailed()),
        );
        final blocked = await cutoverWith([
          FixtureOwner('pilot', File('${directory.path}/pilot.sqlite')),
          later,
        ]).prepare();
        expect(
          blocked,
          isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
            (err) => err.failure,
            'failure',
            isA<LegacyImportVerificationFailed>(),
          ),
        );
        // The marker was created fresh, so the legacy database cannot
        // explain residue held by the later owner.
        expect(later.asked, [false]);
        expect(File('${directory.path}/later.sqlite').existsSync(), isFalse);
        expect(await marker.readAsString(), before);

        final admitted = ProvenanceOwner(
          'later',
          File('${directory.path}/later.sqlite'),
        );
        final result = await cutoverWith([
          FixtureOwner('pilot', File('${directory.path}/pilot.sqlite')),
          admitted,
        ]).prepare();
        expect(result, isA<Ok<RuntimeAdmission, LegacyImportFailure>>());
        await (result as Ok<RuntimeAdmission, LegacyImportFailure>).value
            .close();
        expect(admitted.asked, [false]);
        expect(File('${directory.path}/later.sqlite').existsSync(), isTrue);
      },
    );
  });

  for (final (version, initialFresh) in [(1, true), (1, false), (2, true)]) {
    test(
      'a v$version marker with initialFresh=$initialFresh checks an owner it '
      'never admitted',
      () async {
        final legacy = FixtureDatabase(
          File('${directory.path}/legacy.sqlite'),
          legacy: true,
        );
        await legacy.customStatement('SELECT 1');
        await legacy.close();
        final marker = File('${directory.path}/coordination/split-v1.json');
        await marker.parent.create();
        await marker.writeAsString(
          jsonEncode({
            'version': version,
            'protocol': 'split-v1',
            'state': 'importing',
            'sourceSchemaVersion': 16,
            'initialFresh': initialFresh,
            'sourceEstablished': true,
            'origins': {'pilot': 'legacy', 'later': 'legacy'},
            if (version == 2) 'admittedOwners': <String>[],
          }),
        );
        final later = ProvenanceOwner(
          'later',
          File('${directory.path}/later.sqlite'),
          verdict: const Err(LegacyImportVerificationFailed()),
        );
        final fixture = fixtureCutover(directory);
        final blocked = await StorageCutover(
          directory: fixture.directory,
          legacy: fixture.legacy,
          expectedOwners: fixture.expectedOwners,
          participants: [later],
        ).prepare();
        expect(
          blocked,
          isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
            (err) => err.failure,
            'failure',
            isA<LegacyImportVerificationFailed>(),
          ),
        );
        expect(later.asked, [!initialFresh]);
        expect(File('${directory.path}/later.sqlite').existsSync(), isFalse);
      },
    );
  }

  for (final initialFresh in [true, false]) {
    test(
      'an owner joining a kept marker keeps its legacy origin and imports the '
      'database that now exists (initialFresh=$initialFresh)',
      () async {
        final legacy = FixtureDatabase(
          File('${directory.path}/legacy.sqlite'),
          legacy: true,
        );
        await legacy.customStatement('SELECT 1');
        await legacy.close();
        final marker = File('${directory.path}/coordination/split-v1.json');
        await marker.parent.create();
        await marker.writeAsString(
          jsonEncode({
            'version': 2,
            'protocol': 'split-v1',
            'state': 'importing',
            'sourceSchemaVersion': 16,
            'initialFresh': initialFresh,
            'sourceEstablished': true,
            'origins': {'pilot': 'legacy', 'later': 'legacy'},
            'admittedOwners': <String>[],
          }),
        );
        final later = ProvenanceOwner(
          'later',
          File('${directory.path}/later.sqlite'),
        );
        final fixture = fixtureCutover(directory);
        final result = await StorageCutover(
          directory: fixture.directory,
          legacy: fixture.legacy,
          expectedOwners: fixture.expectedOwners,
          participants: [later],
        ).prepare();
        expect(result, isA<Ok<RuntimeAdmission, LegacyImportFailure>>());
        await (result as Ok<RuntimeAdmission, LegacyImportFailure>).value
            .close();
        expect(later.prepared, [OwnerOrigin.legacy]);
        final published =
            jsonDecode(await marker.readAsString()) as Map<String, Object?>;
        expect(
          (published['origins'] as Map<String, Object?>)['later'],
          'legacy',
        );
      },
    );
  }

  test('unknown marker blocks background and foreground', () async {
    final marker = File('${directory.path}/coordination/split-v1.json');
    await marker.parent.create();
    await marker.writeAsString('{"version":999}');
    expect(await fixtureCutover(directory).prepare(), isA<Err>());
    expect(await fixtureCutover(directory).admit(), isA<Err>());
  });

  test('the current marker rejects a missing admission manifest', () async {
    await (await prepare()).close();
    final marker = File('${directory.path}/coordination/split-v1.json');
    final data =
        (jsonDecode(await marker.readAsString()) as Map<String, Object?>)
          ..remove('admittedOwners');
    await marker.writeAsString(jsonEncode(data));
    final result = await fixtureCutover(directory).prepare();
    if (result case Ok(:final value)) await value.close();
    expect(result, isA<Err<RuntimeAdmission, LegacyImportFailure>>());
  });

  for (final entry in <String, Result<OwnerReadiness, LegacyImportFailure>>{
    'unavailable': const Err(LegacyImportUnavailable()),
    'verification failure': const Err(LegacyImportVerificationFailed()),
    'deferred': const Err(LegacyImportDeferred()),
    'pending': const Ok(OwnerReadiness.pending),
  }.entries) {
    final result = entry.value;
    test(
      'admission preserves inspection classification ${entry.key}',
      () async {
        await (await prepare()).close();
        final fixture = fixtureCutover(directory);
        final coordinator = StorageCutover(
          directory: fixture.directory,
          legacy: fixture.legacy,
          expectedOwners: fixture.expectedOwners,
          participants: [_InspectionOwner(directory, result)],
        );
        final admitted = await coordinator.admit();
        expect(admitted, isA<Err<RuntimeAdmission, LegacyImportFailure>>());
        final failure =
            (admitted as Err<RuntimeAdmission, LegacyImportFailure>).failure;
        switch (result) {
          case Err(failure: final expected):
            expect(identical(failure, expected), isTrue);
          case Ok():
            expect(failure, isA<LegacyImportDeferred>());
        }
        // Failed inspection must close its shared admission.
        await (await prepare()).close();
      },
    );
  }

  test('marker write failure preserves an absent source', () async {
    final temporary = Directory(
      '${directory.path}/coordination/split-v1.json.tmp',
    );
    await temporary.create(recursive: true);
    expect(await fixtureCutover(directory).prepare(), isA<Err>());
    expect(File('${directory.path}/legacy.sqlite').existsSync(), isFalse);
    expect(temporary.existsSync(), isTrue);
  });

  test(
    'marker error after rename is recovered by rereading the published state',
    () async {
      final failed = fixtureCutover(
        directory,
        durableStep: (step) async {
          if (step == 'marker-initial-renamed') {
            throw const FileSystemException(
              'injected directory barrier failure',
            );
          }
        },
      );
      expect(await failed.prepare(), isA<Err>());
      expect(
        File('${directory.path}/coordination/split-v1.json').existsSync(),
        isTrue,
      );
      await (await prepare()).close();
      await (await prepare()).close();
    },
  );

  test(
    'marker cannot turn an upgrade into unestablished fresh setup',
    () async {
      final marker = File('${directory.path}/coordination/split-v1.json');
      await marker.parent.create();
      await marker.writeAsString(
        jsonEncode({
          'version': 1,
          'protocol': 'split-v1',
          'state': 'importing',
          'sourceSchemaVersion': 16,
          'initialFresh': false,
          'sourceEstablished': false,
          'origins': {'pilot': 'legacy', 'later': 'legacy'},
        }),
      );
      expect(await fixtureCutover(directory).prepare(), isA<Err>());
      expect(File('${directory.path}/legacy.sqlite').existsSync(), isFalse);
    },
  );

  for (final step in [
    'marker-initial-flushed',
    'marker-initial-renamed',
    'marker-established-flushed',
    'marker-established-renamed',
    'marker',
    'source-prepared',
    'source-established',
    'owner-pilot',
    'marker-owner-pilot-flushed',
    'marker-owner-pilot-renamed',
  ]) {
    test('SIGKILL after $step resumes twice without recopy', () async {
      final child = await Process.start(dartExecutable, [
        'run',
        'test/support/coordinator_child.dart',
        directory.path,
        step,
      ]);
      final errors = child.stderr.transform(utf8.decoder).join();
      try {
        final ready = await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .firstWhere((line) => line == 'ready:$step')
            .timeout(const Duration(seconds: 60));
        expect(ready, 'ready:$step');
        child.kill(ProcessSignal.sigkill);
        expect(await child.exitCode, -9);
      } on Exception {
        child.kill(ProcessSignal.sigkill);
        fail('Child did not reach durable step: ${await errors}');
      } finally {
        child.kill(ProcessSignal.sigkill);
        await child.exitCode;
      }
      for (var attempt = 0; attempt < 2; attempt++) {
        await (await prepare()).close();
      }
      final check = FixtureDatabase(File('${directory.path}/pilot.sqlite'));
      expect(
        (await check.customSelect('SELECT data FROM sample').getSingle())
            .read<String>('data'),
        'initial-pilot',
      );
      await check.close();
    });
  }
}

class _InspectionOwner extends FixtureOwner {
  final Result<OwnerReadiness, LegacyImportFailure> result;
  _InspectionOwner(Directory directory, this.result)
    : super('pilot', File('${directory.path}/pilot.sqlite'));

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    RuntimeAdmission admission,
  ) async => result;
}
