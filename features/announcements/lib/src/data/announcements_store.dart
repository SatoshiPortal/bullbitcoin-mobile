import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/owner_database.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../domain/announcement_dismissals.dart';
import '../domain/announcements_failure.dart';
import 'announcements_database.dart';

const _owner = 'announcements';

final class AnnouncementsStore implements AnnouncementDismissals {
  final OwnerDatabase<AnnouncementsDatabase> _store;

  const AnnouncementsStore._(this._store);

  static LegacyImportParticipant participant(
    File file, {
    void Function(String message)? warning,
  }) => ProjectedOwner(
    ownerId: _owner,
    file: file,
    tables: const [
      OwnerTableCopy(
        'dismissed_announcements',
        'announcement_id,dismissed_at',
        orderBy: 'announcement_id',
      ),
    ],
    open: (admission, {required existing}) =>
        _open(file, admission, existing: existing),
    onRejected: (reason) =>
        warning?.call('storage.cutover.rejected owner=$_owner reason=$reason'),
  );

  static Future<Result<AnnouncementsStore, AnnouncementsFailure>> open(
    File file,
    RuntimeAdmission admission,
  ) async {
    final opened = await _open(file, admission, existing: true);
    if (opened case Ok(:final value)) {
      final receipt = await ownerReadiness(value.database, _owner);
      if (receipt case Ok(
        value: OwnerReadiness.imported || OwnerReadiness.initialized,
      )) {
        return Ok(AnnouncementsStore._(value));
      }
      await value.handle.close();
    }
    return const Err(AnnouncementStorageFailure('Dismissals unavailable'));
  }

  Future<void> close() => _store.handle.close();

  @override
  Future<Result<List<Dismissal>, AnnouncementsFailure>> read() async {
    final db = _store.database;
    try {
      final rows = await db.select(db.dismissedAnnouncements).get();
      return Ok([
        for (final row in rows)
          (id: row.announcementId, dismissedAt: row.dismissedAt),
      ]);
    } on Exception {
      return const Err(AnnouncementStorageFailure('Dismissal read failed'));
    }
  }

  @override
  Future<Result<void, AnnouncementsFailure>> dismiss(
    String id,
    DateTime at,
  ) async {
    final db = _store.database;
    try {
      await db
          .into(db.dismissedAnnouncements)
          .insertOnConflictUpdate(
            DismissedAnnouncementsCompanion.insert(
              announcementId: id,
              dismissedAt: at,
            ),
          );
      return const Ok(null);
    } on Exception {
      return const Err(AnnouncementStorageFailure('Dismissal write failed'));
    }
  }
}

Future<Result<OwnerDatabase<AnnouncementsDatabase>, LegacyImportFailure>> _open(
  File file,
  LifecycleAdmission admission, {
  required bool existing,
}) => OwnerDatabase.open(
  admission: admission,
  openExecutor: Secrets.databaseOpener<LegacyImportFailure>(
    module: _owner,
    name: 'main',
    file: file,
    schema: AnnouncementsDatabase.schema,
    deferred: const LegacyImportDeferred(),
    unavailable: const LegacyImportUnavailable(),
  )(existing),
  create: AnnouncementsDatabase.new,
);
