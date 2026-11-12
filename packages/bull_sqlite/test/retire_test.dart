import 'dart:io';

import 'package:bull_sqlite/bull_sqlite.dart';
import 'package:bull_sqlite/src/exceptions.dart';
import 'package:bull_sqlite/src/retire.dart';
import 'package:bull_sqlite/src/sqlite_family.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late String path;
  late SqliteFamily family;

  setUp(() {
    path = freshPath();
    family = SqliteFamily(path);
    for (final member in family.members) {
      member.writeAsStringSync('x');
    }
  });
  tearDown(() => Directory(family.directory).deleteSync(recursive: true));

  List<String> names() => Directory(
    family.directory,
  ).listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  test('a deletion removes every member and then the marker', () {
    expect(
      EncryptedSqlite.retire(path, const Retirement.delete()),
      isA<Ok<void, SqliteStorageFailure>>(),
    );
    expect(names(), isEmpty);
  });

  test('a quarantine renames every member and keeps nothing else', () {
    expect(
      EncryptedSqlite.retire(
        path,
        const Retirement.quarantine('.unreadable-1'),
      ),
      isA<Ok<void, SqliteStorageFailure>>(),
    );
    expect(
      names(),
      [
        for (final m in family.members)
          '${m.uri.pathSegments.last}.unreadable-1',
      ]..sort(),
    );
  });

  for (final step in RetirementStep.values.where(
    (s) => s != RetirementStep.published,
  )) {
    test(
      'interrupted after ${step.name}, the decided retirement is finished on resume',
      () {
        expect(
          () => retire(
            family,
            const Retirement.quarantine('.q'),
            onStep: (s) {
              if (s == step) throw const FileSystemException('injected');
            },
          ),
          throwsA(isA<FileSystemException>()),
        );
        if (step == RetirementStep.marked) {
          // One member already moved, as if the crash came between two renames.
          family.wal.renameSync('${family.wal.path}.q');
        }
        // A later request for another kind of retirement does not override the decided one.
        final resumed = EncryptedSqlite.resumeRetirement(path);
        expect(
          resumed,
          isA<Ok<bool, SqliteStorageFailure>>().having(
            (r) => r.value,
            'resumed',
            step != RetirementStep.unmarked,
          ),
        );
        expect(family.retirement.existsSync(), isFalse);
        for (final member in family.members) {
          expect(member.existsSync(), isFalse, reason: member.path);
          expect(
            File('${member.path}.q').existsSync(),
            isTrue,
            reason: member.path,
          );
        }
      },
    );
  }

  test('a pending marker wins over a new request', () {
    family.retirement.writeAsStringSync('quarantine:.kept');
    expect(
      EncryptedSqlite.retire(path, const Retirement.delete()),
      isA<Ok<void, SqliteStorageFailure>>(),
    );
    expect(File('$path.kept').existsSync(), isTrue);
  });

  test(
    'a member and its quarantine copy both present stop everything, marker kept',
    () {
      File('$path.q').writeAsStringSync('other');
      expect(
        EncryptedSqlite.retire(path, const Retirement.quarantine('.q')),
        isA<Err<void, SqliteStorageFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<SqliteInconsistentFailure>(),
        ),
      );
      expect(family.retirement.existsSync(), isTrue);
      expect(family.database.readAsStringSync(), 'x');
      expect(File('$path.q').readAsStringSync(), 'other');
    },
  );

  test('an empty marker was never decided: the request replaces it', () {
    family.retirement.writeAsStringSync('');
    expect(
      EncryptedSqlite.resumeRetirement(path),
      isA<Ok<bool, SqliteStorageFailure>>().having(
        (r) => r.value,
        'resumed',
        isFalse,
      ),
    );
    expect(
      EncryptedSqlite.retire(path, const Retirement.delete()),
      isA<Ok<void, SqliteStorageFailure>>(),
    );
    expect(names(), isEmpty);
  });

  test(
    'an unreadable marker blocks a resume and a quarantine, but not a consented deletion',
    () {
      family.retirement.writeAsStringSync('garbage');
      expect(
        () => resumeRetirement(family),
        throwsA(isA<InconsistentFamilyException>()),
      );
      expect(
        EncryptedSqlite.retire(path, const Retirement.quarantine('.q')),
        isA<Err<void, SqliteStorageFailure>>(),
      );
      expect(family.database.existsSync(), isTrue);
      expect(
        EncryptedSqlite.retire(path, const Retirement.delete()),
        isA<Ok<void, SqliteStorageFailure>>(),
      );
      expect(names(), isEmpty);
    },
  );

  test('no marker, nothing to resume', () {
    expect(
      EncryptedSqlite.resumeRetirement(path),
      isA<Ok<bool, SqliteStorageFailure>>().having(
        (r) => r.value,
        'resumed',
        isFalse,
      ),
    );
    expect(family.database.existsSync(), isTrue);
  });
}
