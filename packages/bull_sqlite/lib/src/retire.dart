import 'dart:convert';
import 'dart:io';

import 'package:bull_sqlite/src/directory_barrier.dart';
import 'package:bull_sqlite/src/exceptions.dart';
import 'package:bull_sqlite/src/sqlite_family.dart';
import 'package:meta/meta.dart';

/// What a retirement does with the family's files.
sealed class Retirement {
  const Retirement();

  /// Deletes every member. For a reset the user consented to.
  const factory Retirement.delete() = DeleteRetirement;

  /// Renames every member to `<member><suffix>`, keeping it for diagnosis.
  const factory Retirement.quarantine(String suffix) = QuarantineRetirement;

  String get _marker;

  static Retirement? _parse(String marker) {
    if (marker == 'delete') return const DeleteRetirement();
    const prefix = 'quarantine:';
    if (marker.startsWith(prefix) && marker.length > prefix.length) {
      return QuarantineRetirement(marker.substring(prefix.length));
    }
    return null;
  }
}

final class DeleteRetirement extends Retirement {
  const DeleteRetirement();

  @override
  String get _marker => 'delete';
}

final class QuarantineRetirement extends Retirement {
  final String suffix;

  const QuarantineRetirement(this.suffix);

  @override
  String get _marker => 'quarantine:$suffix';
}

/// The points of [retire], in order. Tests stop the process at each one.
enum RetirementStep { marked, membersRetired, unmarked, published }

/// Deletes or quarantines a whole family, resumably.
///
/// 1. Writes the marker, flushes it and syncs the directory: from then on the retirement is decided, and every later start resumes it before opening anything.
/// 2. Retires each member: a member whose source is gone was already done; a member whose quarantine name is already taken stops everything (two copies, no safe choice), marker kept.
/// 3. Syncs the directory, removes the marker, syncs again. The retirement is complete only once that last sync succeeds; a failure leaves it for the next attempt, which re-runs step 2 on a family that nothing has written to since.
///
/// If a readable marker is already present, it wins over [retirement]: an interrupted retirement is finished as it was decided. An empty marker was never made durable, so nothing was retired under it and [retirement] replaces it. An unreadable one blocks everything except a deletion, which only ever runs with the user's consent and leaves nothing to disagree about.
void retire(
  SqliteFamily family,
  Retirement retirement, {
  @visibleForTesting void Function(RetirementStep step)? onStep,
}) {
  final Retirement decided;
  switch (_readMarker(family)) {
    case _NoMarker():
      decided = retirement;
      _writeMarker(family, decided);
    case _Decided(retirement: final pending):
      decided = pending;
      // An earlier attempt may have crashed between writing the marker and making it durable. Nothing is touched until it is.
      _makeDurable(family);
    case _Unreadable():
      if (retirement is! DeleteRetirement) {
        throw const InconsistentFamilyException('unreadable retirement marker');
      }
      decided = retirement;
      _writeMarker(family, decided);
  }
  onStep?.call(RetirementStep.marked);

  for (final member in family.members) {
    switch (decided) {
      case DeleteRetirement():
        if (member.existsSync()) member.deleteSync();
      case QuarantineRetirement(:final suffix):
        final destination = File('${member.path}$suffix');
        final present = member.existsSync();
        if (present && destination.existsSync()) {
          throw const InconsistentFamilyException(
            'a member and its quarantine copy both exist',
          );
        }
        if (present) member.renameSync(destination.path);
    }
  }
  DirectoryBarrier.sync(family.directory);
  onStep?.call(RetirementStep.membersRetired);

  family.retirement.deleteSync();
  onStep?.call(RetirementStep.unmarked);
  DirectoryBarrier.sync(family.directory);
  onStep?.call(RetirementStep.published);
}

/// Finishes an interrupted retirement, if there is one. Returns whether there was.
///
/// Throws [InconsistentFamilyException] for a marker that cannot be read: only the user can decide that family's fate.
bool resumeRetirement(SqliteFamily family) {
  switch (_readMarker(family)) {
    case _NoMarker():
      return false;
    case _Decided(retirement: final pending):
      retire(family, pending);
      return true;
    case _Unreadable():
      throw const InconsistentFamilyException('unreadable retirement marker');
  }
}

void _makeDurable(SqliteFamily family) {
  final marker = family.retirement.openSync(mode: FileMode.append);
  try {
    marker.flushSync();
  } finally {
    marker.closeSync();
  }
  DirectoryBarrier.sync(family.directory);
}

void _writeMarker(SqliteFamily family, Retirement retirement) {
  final marker = family.retirement.openSync(mode: FileMode.writeOnly);
  try {
    marker.truncateSync(0);
    marker.writeStringSync(retirement._marker);
    marker.flushSync();
  } finally {
    marker.closeSync();
  }
  DirectoryBarrier.sync(family.directory);
}

sealed class _Marker {
  const _Marker();
}

final class _NoMarker extends _Marker {
  const _NoMarker();
}

final class _Decided extends _Marker {
  final Retirement retirement;

  const _Decided(this.retirement);
}

final class _Unreadable extends _Marker {
  const _Unreadable();
}

_Marker _readMarker(SqliteFamily family) {
  if (!family.retirement.existsSync()) return const _NoMarker();
  final String text;
  try {
    text = utf8.decode(family.retirement.readAsBytesSync());
  } on FormatException {
    // Bytes this package never writes: a damaged marker, as unreadable as garbage text.
    return const _Unreadable();
  }
  // Written and flushed before any member is touched: empty means the crash came first.
  if (text.isEmpty) return const _NoMarker();
  final decided = Retirement._parse(text);
  return decided == null ? const _Unreadable() : _Decided(decided);
}
