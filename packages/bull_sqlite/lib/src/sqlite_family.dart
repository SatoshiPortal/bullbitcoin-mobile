import 'dart:io';

import 'package:path/path.dart' as p;

/// What the main file of a database family is, read from disk without opening it.
enum SqliteFileState {
  /// No main file, and no other member.
  absent,

  /// A zero-byte main file and no other member: what SQLite leaves when a first open is interrupted before the first page.
  empty,

  /// The SQLite header in clear.
  plaintext,

  /// At least one page and another header. Encrypted, as far as a header can tell; only opening with the key proves it.
  possiblyEncrypted,

  /// A state with no safe automatic decision: a main file of 1 to 15 bytes, an empty or missing main file next to any other member, or a retirement left half done.
  inconsistent,
}

/// One database and every file SQLite or this package puts next to it.
///
/// The family is the unit of every decision: a header says little on its own, a `-wal` without its database says a lot.
final class SqliteFamily {
  static const _header = 'SQLite format 3\u0000';
  static const _headerLength = 16;

  final String path;

  SqliteFamily(this.path);

  File get database => File(path);
  File get wal => File('$path-wal');
  File get shm => File('$path-shm');
  File get journal => File('$path-journal');

  /// The encrypted copy under construction. Never the only copy of anything: it is published by one rename over [database].
  File get candidate => File('$path.encryption-tmp');
  File get candidateJournal => File('$path.encryption-tmp-journal');

  /// Present while a retirement (deletion or quarantine) is under way. Not a member: the retirement removes it last.
  File get retirement => File('$path.retire-pending');

  String get directory => p.dirname(path);

  /// Every file of the family but [retirement], main file last: what a retirement moves or deletes.
  List<File> get members => [
    wal,
    shm,
    journal,
    candidate,
    candidateJournal,
    database,
  ];

  /// Reads lengths and the first 16 bytes. Opens nothing with SQLite and deletes nothing.
  SqliteFileState inspect() {
    if (retirement.existsSync()) return SqliteFileState.inconsistent;
    // Fail closed: next to a missing or empty main file, any other member — even an empty one, even `-shm` — is a state this package did not leave, and the owner decides with the user.
    final othersExist = [
      wal,
      shm,
      journal,
      candidate,
      candidateJournal,
    ].any((file) => file.existsSync());

    if (!database.existsSync()) {
      return othersExist
          ? SqliteFileState.inconsistent
          : SqliteFileState.absent;
    }
    final length = database.lengthSync();
    if (length == 0) {
      return othersExist ? SqliteFileState.inconsistent : SqliteFileState.empty;
    }
    if (length < _headerLength) return SqliteFileState.inconsistent;
    return _readHeader() == _header
        ? SqliteFileState.plaintext
        : SqliteFileState.possiblyEncrypted;
  }

  String _readHeader() {
    final file = database.openSync();
    try {
      return String.fromCharCodes(file.readSync(_headerLength));
    } finally {
      file.closeSync();
    }
  }

  /// Copies a quarantine left next to the database, named `<member>.unreadable-<digits>` (what Payjoin's self-heal has always used). Not members: nothing reads them, and their presence decides nothing. A deletion removes them with the family, so that a reset leaves no copy behind, plaintext ones from older releases included.
  List<File> get quarantined {
    final directory = Directory(this.directory);
    if (!directory.existsSync()) return const [];
    final base = RegExp.escape(p.basename(path));
    final pattern = RegExp(
      '^$base(-wal|-shm|-journal|\\.encryption-tmp|\\.encryption-tmp-journal)?\\.unreadable-[0-9]+\$',
    );
    return [
      for (final entity in directory.listSync(followLinks: false))
        if (entity is File && pattern.hasMatch(p.basename(entity.path))) entity,
    ];
  }
}
