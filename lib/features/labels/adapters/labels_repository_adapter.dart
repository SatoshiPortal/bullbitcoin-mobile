import 'package:bb_mobile/core/storage/storage.dart';
import 'package:bb_mobile/core/storage/backup_revision_recorder.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';

class DriftLabelsRepositoryAdapter implements LabelsRepositoryPort {
  final SqliteDatabase _database;
  final BackupRevisionRecorder _revisions;

  DriftLabelsRepositoryAdapter({required SqliteDatabase database})
    : _database = database,
      _revisions = DriftBackupRevisionRecorder(database);

  @override
  Future<LabelEntity> store(NewLabel newLabel) async {
    // Validate BEFORE writing: constructing a LabelEntity is what enforces
    // its invariants (see LabelEntity._validateReference), and it must
    // throw here — before the insert below — or a caller told the store
    // failed has in fact already had its row persisted (the previous shape
    // built the companion from the unvalidated newLabel directly and only
    // constructed a LabelEntity afterwards, purely to shape the return
    // value, by which point the row was already committed).
    LabelEntity(
      id: 0, // unknown before insert; only the validation side effect matters
      type: newLabel.type,
      label: newLabel.label,
      reference: newLabel.reference,
      origin: newLabel.origin,
    );

    final normalized = NewLabel(
      id: newLabel.id,
      type: newLabel.type,
      reference: newLabel.reference,
      label: LabelEntity.sanitizeLabel(newLabel.label),
      origin: newLabel.origin,
    );
    final companion = LabelMapper.newLabelEntityToCompanion(normalized);
    return _database.transaction(() async {
      final previous =
          await (_database.select(_database.labels)..where(
                (row) =>
                    row.label.equals(normalized.label) &
                    row.reference.equals(normalized.reference),
              ))
              .getSingleOrNull();
      final row = await _database
          .into(_database.labels)
          .insertReturning(
            companion,
            onConflict: DoUpdate(
              (old) => companion,
              target: [_database.labels.label, _database.labels.reference],
            ),
          );
      // Label/reference identify the upsert target. Type and origin are the
      // remaining backed-up fields; the local row ID is not part of a backup.
      if (previous == null ||
          previous.type != row.type ||
          previous.origin != row.origin) {
        await _revisions.recordCommittedMutation();
      }
      return LabelMapper.toLabelEntity(row);
    });
  }

  @override
  Future<void> storeAll(List<NewLabel> newLabels) async {
    await _database.transaction(() async {
      for (final label in newLabels) {
        await store(label);
      }
    });
  }

  @override
  Future<List<LabelEntity>> fetchByLabel(String label) async {
    final rows = await _database.managers.labels
        .filter((l) => l.label(label))
        .get();
    return _mapRowsTolerantly(rows);
  }

  @override
  Future<List<LabelEntity>> fetchByReference(String reference) async {
    final rows = await _database.managers.labels
        .filter((l) => l.reference(reference))
        .get();
    return _mapRowsTolerantly(rows);
  }

  @override
  Future<LabelEntity?> fetchById(int id) async {
    final row = await _database.managers.labels
        .filter((l) => l.id(id))
        .getSingleOrNull();
    return row != null ? LabelMapper.toLabelEntity(row) : null;
  }

  @override
  Future<void> trash(int id) async {
    await _database.transaction(() async {
      final deleted = await _database.managers.labels
          .filter((l) => l.id(id))
          .delete();
      if (deleted > 0) await _revisions.recordCommittedMutation();
    });
  }

  @override
  Future<List<LabelEntity>> fetchAll({bool strict = false}) async {
    final rows = await _database.managers.labels.get();
    if (strict) return rows.map(LabelMapper.toLabelEntity).toList();
    return _mapRowsTolerantly(rows);
  }

  /// Maps each row independently and drops (with a log) any row that fails
  /// [LabelEntity]'s validation, instead of letting `.map().toList()`
  /// propagate the first bad row's exception and discard every valid label
  /// in the same query. Every fetch method here feeds every label lookup in
  /// the app (including the wallet transaction list's per-input/output
  /// label enrichment), so one corrupt row used to silently blank out label
  /// data everywhere it was read.
  List<LabelEntity> _mapRowsTolerantly(List<LabelRow> rows) {
    final entities = <LabelEntity>[];
    for (final row in rows) {
      try {
        entities.add(LabelMapper.toLabelEntity(row));
      } catch (e) {
        log.warning(
          'Skipping corrupt label row id=${row.id}: failed to map to a '
          'LabelEntity',
          error: e,
        );
      }
    }
    return entities;
  }
}
