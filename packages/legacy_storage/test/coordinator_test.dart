import 'dart:convert';
import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

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
    'established missing source and orphan sidecars never create a source',
    () async {
      await (await prepare()).close();
      await File('${directory.path}/legacy.sqlite').delete();
      expect(await fixtureCutover(directory).prepare(), isA<Err>());
      expect(File('${directory.path}/legacy.sqlite').existsSync(), isFalse);
    },
  );

  test('new source with orphan WAL is not interpreted as fresh', () async {
    await File('${directory.path}/legacy.sqlite-wal').writeAsString('orphan');
    expect(await fixtureCutover(directory).prepare(), isA<Err>());
    expect(File('${directory.path}/legacy.sqlite').existsSync(), isFalse);
  });

  test('unknown marker blocks background and foreground', () async {
    final marker = File('${directory.path}/coordination/split-v1.json');
    await marker.parent.create();
    await marker.writeAsString('{"version":999}');
    expect(await fixtureCutover(directory).prepare(), isA<Err>());
    expect(await fixtureCutover(directory).admit(), isA<Err>());
  });

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
  ]) {
    test('SIGKILL after $step resumes twice without recopy', () async {
      final child = await Process.start(Platform.resolvedExecutable, [
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
