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
    () async =>
        directory = await Directory.systemTemp.createTemp('retirement-'),
  );
  tearDown(() => directory.delete(recursive: true));

  test('v1 without admitted owners defers then prepares a v2 marker', () async {
    final cutover = fixtureCutover(directory, later: true);
    final prepared = await cutover.prepare();
    await (prepared as Ok<RuntimeAdmission, LegacyImportFailure>).value.close();
    final marker = File('${directory.path}/coordination/split-v1.json');
    final value = jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
    expect(value['version'], 2);
    value['version'] = 1;
    value.remove('admittedOwners');
    marker.writeAsStringSync(jsonEncode(value));
    expect(
      await cutover.admit(),
      isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<LegacyImportDeferred>(),
      ),
    );
    final resumed = await cutover.prepare();
    expect(resumed, isA<Ok<RuntimeAdmission, LegacyImportFailure>>());
    await (resumed as Ok<RuntimeAdmission, LegacyImportFailure>).value.close();
    final upgraded =
        jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
    expect(upgraded['version'], 2);
    expect(upgraded['admittedOwners'], ['later', 'pilot']);
    final admitted = await cutover.admit();
    expect(admitted, isA<Ok<RuntimeAdmission, LegacyImportFailure>>());
    await (admitted as Ok<RuntimeAdmission, LegacyImportFailure>).value.close();
  });

  test(
    'v3 retiring and retired markers block admission and never delete',
    () async {
      final cutover = fixtureCutover(directory, later: true);
      final prepared = await cutover.prepare();
      await (prepared as Ok<RuntimeAdmission, LegacyImportFailure>).value
          .close();
      final marker = File('${directory.path}/coordination/split-v1.json');
      final source = File('${directory.path}/legacy.sqlite');
      final original =
          jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
      for (final state in ['retiring', 'retired']) {
        final value = Map<String, dynamic>.from(original)
          ..['version'] = 3
          ..['state'] = state
          ..['retire'] = {'intentAt': 1, 'doneSteps': <String>[]};
        marker.writeAsStringSync(jsonEncode(value));
        final before = source.readAsBytesSync();
        final expected = state == 'retiring'
            ? isA<LegacyImportDeferred>()
            : isA<LegacyImportUnavailable>();
        expect(
          await cutover.admit(),
          isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
            (v) => v.failure,
            'failure',
            expected,
          ),
        );
        expect(
          await cutover.prepare(),
          isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
            (v) => v.failure,
            'failure',
            expected,
          ),
        );
        // A separate process forces the OS-lock contention path, rather than
        // the in-isolate runtime admission guard.
        final holder = await Process.start('bash', [
          '-c',
          r'exec 9>>"$1" && flock -s 9 && echo ready && read -r release',
          'holder',
          '${directory.path}/coordination/lifecycle.lock',
        ], runInShell: false);
        try {
          expect(
            await holder.stdout
                .transform(utf8.decoder)
                .transform(const LineSplitter())
                .first,
            'ready',
          );
          expect(
            await cutover.prepare(timeout: Duration.zero),
            isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
              (v) => v.failure,
              'fallback failure',
              expected,
            ),
          );
        } finally {
          holder.stdin.writeln('release');
          await holder.stdin.close();
          await holder.exitCode;
        }
        final report = await cutover.evaluateRetirement();
        expect(report.eligible, isFalse);
        expect(report.blockers, [
          state == 'retiring' ? 'retiring_in_progress' : 'already_retired',
        ]);
        expect(source.readAsBytesSync(), before);
        expect(jsonDecode(marker.readAsStringSync())['state'], state);
      }
    },
  );

  test('exclusive lease and complete participant proof are required', () async {
    final pilot = FixtureRetirement('pilot');
    final later = FixtureRetirement('later');
    final cutover = fixtureCutover(
      directory,
      later: true,
      retirement: [pilot, later],
    );
    final prepared = await cutover.prepare();
    final runtime =
        (prepared as Ok<RuntimeAdmission, LegacyImportFailure>).value;
    expect(
      (await cutover.evaluateRetirement(timeout: Duration.zero)).eligible,
      isFalse,
    );
    await runtime.close();
    expect(
      (await cutover.evaluateRetirement()).blockers,
      contains('recovery_provenance_unavailable'),
    );
    expect(pilot.calls, ['verify']);
    expect(later.calls, ['verify']);
    later.verdict = const Err(LegacyImportVerificationFailed());
    final refused = await cutover.evaluateRetirement();
    expect(refused.blockers, [
      'proof:later:LegacyImportVerificationFailed',
      'recovery_provenance_unavailable',
    ]);
    expect(pilot.calls, ['verify', 'verify']);
    expect(later.calls, ['verify', 'verify']);
    expect(File('${directory.path}/legacy.sqlite').existsSync(), isTrue);
  });
  test('malformed v3 marker is unavailable and reported unreadable', () async {
    final cutover = fixtureCutover(directory, later: true);
    final prepared = await cutover.prepare();
    await (prepared as Ok<RuntimeAdmission, LegacyImportFailure>).value.close();
    final marker = File('${directory.path}/coordination/split-v1.json');
    final value = jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
    value['version'] = 3;
    value['state'] = 'retiring';
    value['retire'] = {'intentAt': 'invalid', 'doneSteps': <String>[]};
    marker.writeAsStringSync(jsonEncode(value));
    expect(
      await cutover.admit(),
      isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
        (v) => v.failure,
        'failure',
        isA<LegacyImportUnavailable>(),
      ),
    );
    expect(
      await cutover.prepare(),
      isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
        (v) => v.failure,
        'failure',
        isA<LegacyImportUnavailable>(),
      ),
    );
    expect((await cutover.evaluateRetirement()).blockers, [
      'marker_unreadable',
    ]);
  });
  test('malformed v3 retirement fields are rejected by the decoder', () async {
    final cutover = fixtureCutover(directory, later: true);
    final prepared = await cutover.prepare();
    await (prepared as Ok<RuntimeAdmission, LegacyImportFailure>).value.close();
    final marker = File('${directory.path}/coordination/split-v1.json');
    final original =
        jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
    final invalidRetire = <Object?>[
      null,
      false,
      'not a map',
      {'intentAt': 'invalid', 'doneSteps': <String>[]},
      {'doneSteps': <String>[]},
      {'intentAt': 1, 'doneSteps': 'invalid'},
      {
        'intentAt': 1,
        'doneSteps': ['xxxxxxxxxpilot'],
      },
      {
        'intentAt': 1,
        'doneSteps': ['x'],
      },
      {
        'intentAt': 1,
        'doneSteps': ['keychain:pilot', 'keychain:pilot'],
      },
      {
        'intentAt': 1,
        'doneSteps': ['keychain:unknown'],
      },
      {
        'intentAt': 1,
        'doneSteps': ['keychain:'],
      },
    ];
    for (final retire in invalidRetire) {
      final value = Map<String, dynamic>.from(original)
        ..['version'] = 3
        ..['state'] = 'retiring';
      value['retire'] = retire;
      if (retire == false) {
        value.remove('retire');
      }
      marker.writeAsStringSync(jsonEncode(value));
      expect((await cutover.evaluateRetirement()).blockers, [
        'marker_unreadable',
      ], reason: '$retire');
      expect(
        await cutover.admit(),
        isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
          (v) => v.failure,
          'failure',
          isA<LegacyImportUnavailable>(),
        ),
        reason: '$retire',
      );
    }
  });

  test(
    'diagnostic preserves marker and source family in this fixture',
    () async {
      final pilot = FixtureRetirement('pilot');
      final later = FixtureRetirement('later');
      final cutover = fixtureCutover(
        directory,
        later: true,
        retirement: [pilot, later],
      );
      final prepared = await cutover.prepare();
      await (prepared as Ok<RuntimeAdmission, LegacyImportFailure>).value
          .close();
      final marker = File('${directory.path}/coordination/split-v1.json');
      final source = File('${directory.path}/legacy.sqlite');
      final beforeMarker = marker.readAsBytesSync();
      final before = <String, List<int>?>{
        for (final suffix in ['', '-wal', '-shm', '-journal'])
          suffix: File('${source.path}$suffix').existsSync()
              ? File('${source.path}$suffix').readAsBytesSync()
              : null,
      };
      final report = await cutover.evaluateRetirement();
      expect(report.blockers, ['recovery_provenance_unavailable']);
      expect(pilot.calls, ['verify']);
      expect(later.calls, ['verify']);
      expect(marker.readAsBytesSync(), beforeMarker);
      for (final entry in before.entries) {
        final file = File('${source.path}${entry.key}');
        expect(file.existsSync(), entry.value != null, reason: entry.key);
        if (entry.value case final bytes?) {
          expect(file.readAsBytesSync(), bytes, reason: entry.key);
        }
      }
      // This assertion concerns this fixture, not lock-file creation or the
      // SQLite WAL/SHM effects of read-write owner openings in production.
    },
  );
}
