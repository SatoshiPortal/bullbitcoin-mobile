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

  test(
    'a deletion also removes earlier quarantine copies, plaintext ones included',
    () {
      final copies = [
        for (final suffix in ['', '-wal', '-shm'])
          File('$path$suffix.unreadable-1700000000000')
            ..writeAsStringSync('SQLite format 3'),
      ];
      final unrelated = File('${family.directory}/other.sqlite.unreadable-1')
        ..writeAsStringSync('keep');
      final lookalike = File('$path.unreadable-notanumber')
        ..writeAsStringSync('keep');

      expect(
        EncryptedSqlite.retire(path, const Retirement.delete()),
        isA<Ok<void, SqliteStorageFailure>>(),
      );
      for (final copy in copies) {
        expect(copy.existsSync(), isFalse, reason: copy.path);
      }
      expect(unrelated.existsSync(), isTrue);
      expect(lookalike.existsSync(), isTrue);
    },
  );

  test('a quarantine leaves earlier quarantine copies where they are', () {
    final earlier = File('$path.unreadable-1')..writeAsStringSync('earlier');
    expect(
      EncryptedSqlite.retire(
        path,
        const Retirement.quarantine('.unreadable-2'),
      ),
      isA<Ok<void, SqliteStorageFailure>>(),
    );
    expect(earlier.readAsStringSync(), 'earlier');
    expect(File('$path.unreadable-2').existsSync(), isTrue);
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

  test(
    'a marker that is not even text is unreadable: it blocks a resume, but not a consented deletion',
    () {
      family.retirement.writeAsBytesSync([0xff, 0xfe, 0x00, 0xc3]);
      expect(
        () => resumeRetirement(family),
        throwsA(isA<InconsistentFamilyException>()),
      );
      expect(family.database.existsSync(), isTrue);
      expect(
        EncryptedSqlite.retire(path, const Retirement.delete()),
        isA<Ok<void, SqliteStorageFailure>>(),
      );
      expect(names(), isEmpty);
    },
  );

  test('a pending marker is made durable before any member is touched', () {
    family.retirement.writeAsStringSync('delete');
    final steps = <RetirementStep>[];
    retire(
      family,
      const Retirement.delete(),
      onStep: (step) {
        steps.add(step);
        if (step == RetirementStep.marked) {
          // The marker survived and nothing was deleted before this point.
          expect(family.retirement.existsSync(), isTrue);
          expect(family.database.existsSync(), isTrue);
        }
      },
    );
    expect(steps.first, RetirementStep.marked);
    expect(names(), isEmpty);
  });

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
