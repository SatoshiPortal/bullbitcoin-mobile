import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'support/import_fixture.dart';

void main() {
  late Directory directory;
  late File source;
  late File destination;
  late String fixtureKey;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('legacy-drift-');
    source = File('${directory.path}/legacy.sqlite');
    destination = File('${directory.path}/module.sqlite');
    final random = Random.secure();
    fixtureKey = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  });

  tearDown(() => directory.delete(recursive: true));

  test(
    'copies committed WAL rows and replays with the source removed',
    () async {
      final db = SampleDatabase(destination, fixtureKey);
      addTearDown(db.close);
      final legacy = createLegacy(source);
      try {
        expect(await File('${source.path}-wal').exists(), isTrue);
        expect(await importSamples(source, db), isA<Ok>());
        expect(await db.readSamples(), ['one', 'two']);
        expect(await _hasReceipt(db), isTrue);
      } finally {
        legacy.close();
      }
      expect(
        String.fromCharCodes((await destination.readAsBytes()).take(16)),
        isNot('SQLite format 3\u0000'),
      );

      await source.delete();
      expect(await importSamples(source, db), isA<Ok>());
      expect(await source.exists(), isFalse);
      expect(await db.readSamples(), ['one', 'two']);
    },
  );

  test('refuses a missing source or an unexpected source version', () async {
    final db = SampleDatabase(destination, fixtureKey);
    addTearDown(db.close);
    expect(
      await importSamples(source, db),
      isA<Err<void, LegacyImportFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<LegacyImportUnavailable>(),
      ),
    );
    expect(await source.exists(), isFalse);
    final legacy = createLegacy(source)..userVersion = 15;
    addTearDown(legacy.close);
    expect(
      await importSamples(source, db),
      isA<Err<void, LegacyImportFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<LegacySourceSchemaMismatch>(),
      ),
    );
    expect(await _hasReceipt(db), isFalse);
    expect(await db.readSamples(), isEmpty);
    legacy.userVersion = 16;
    expect(await importSamples(source, db), isA<Ok>());
  });

  test('a failed verification rolls back rows and the receipt', () async {
    createLegacy(source).close();
    final db = SampleDatabase(destination, fixtureKey);
    addTearDown(db.close);
    final result = await importLegacyDatabase(
      id: importId,
      source: source,
      sourceSchemaVersion: 16,
      destination: db,
      copyAndVerify: (_) async {
        await db.customStatement("INSERT INTO sample VALUES (1, 'partial')");
        return false;
      },
    );
    expect(
      result,
      isA<Err<void, LegacyImportFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<LegacyImportVerificationFailed>(),
      ),
    );
    expect(await _hasReceipt(db), isFalse);
    expect(await db.readSamples(), isEmpty);
    expect(await importSamples(source, db), isA<Ok>());
  });

  test(
    'background sees neither the pending receipt nor partial rows',
    () async {
      createLegacy(source).close();
      final foreground = SampleDatabase(destination, fixtureKey);
      addTearDown(foreground.close);
      await foreground.readSamples();
      // Two independent executors intentionally share a file in this test.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final background = SampleDatabase(
        destination,
        fixtureKey,
        background: true,
      );
      addTearDown(background.close);
      final reached = Completer<void>();
      final resume = Completer<void>();
      final importing = importSamples(
        source,
        foreground,
        pause: (step) async {
          if (step == 'row-1') {
            reached.complete();
            await resume.future;
          }
        },
      );
      await Future.any([reached.future, importing]);
      try {
        expect(await _hasReceipt(background), isFalse);
        expect(await background.readSamples(), isEmpty);
      } finally {
        resume.complete();
      }
      expect(await importing, isA<Ok>());
      expect(await _hasReceipt(background), isTrue);
      expect(await background.readSamples(), ['one', 'two']);
    },
  );

  for (final step in [
    'create',
    'schema',
    'claim',
    'row-1',
    'row-2',
    'verify',
    'commit',
  ]) {
    test(
      'replays after SIGKILL at $step',
      () async {
        createLegacy(source).close();
        final child = await Process.start(
          Platform.resolvedExecutable,
          [
            'run',
            'test/support/import_child.dart',
            source.path,
            destination.path,
            step,
          ],
          environment: {'BULL_RECIPE_TEST_KEY': fixtureKey},
        );
        final errors = child.stderr.transform(utf8.decoder).join();
        try {
          final ready = await child.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .firstWhere((line) => line.startsWith('ready:$step:'))
              .timeout(const Duration(seconds: 45));
          expect(ready, 'ready:$step:${child.pid}');
          expect(child.kill(ProcessSignal.sigkill), isTrue);
          expect(await child.exitCode, -9);
        } on Exception {
          child.kill(ProcessSignal.sigkill);
          fail('Child did not reach $step: ${await errors}');
        } finally {
          child.kill(ProcessSignal.sigkill);
          await child.exitCode;
        }

        final db = SampleDatabase(destination, fixtureKey);
        addTearDown(db.close);
        final committed = step == 'commit';
        expect(await _hasReceipt(db), committed);
        expect(await db.readSamples(), committed ? ['one', 'two'] : isEmpty);
        expect(await importSamples(source, db), isA<Ok>());
        expect(await _hasReceipt(db), isTrue);
        expect(await db.readSamples(), ['one', 'two']);
      },
      skip: Platform.isWindows,
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }
}

Future<bool> _hasReceipt(SampleDatabase db) async {
  final Ok(:value) = (await hasLegacyImportReceipt(
    db,
    importId,
  )) as Ok<bool, LegacyImportFailure>;
  return value;
}
