import 'package:bb_mobile/core/storage/storage.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';

class DriftLabelsRepositoryAdapter implements LabelsRepositoryPort {
  final SqliteDatabase _database;

  DriftLabelsRepositoryAdapter({required this._database});

  @override
  Future<LabelEntity> store(NewLabel newLabel) async {
    _validateOrThrow(newLabel);

    final companion = LabelMapper.newLabelEntityToCompanion(newLabel);
    final id = await _database
        .into(_database.labels)
        .insert(
          companion,
          onConflict: DoUpdate(
            (old) => companion,
            target: [_database.labels.label, _database.labels.reference],
          ),
        );

    return LabelEntity(
      id: id,
      type: newLabel.type,
      label: newLabel.label,
      reference: newLabel.reference,
      origin: newLabel.origin,
    );
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
    if (row == null) return null;
    try {
      return LabelMapper.toLabelEntity(row);
    } catch (e) {
      log.warning('Skipping corrupt label row ${row.id}: $e');
      return null;
    }
  }

  /// Validates [newLabel]'s reference BEFORE it ever reaches the DB, by
  /// constructing (and discarding) the [LabelEntity] that would represent
  /// it — the constructor throws on a malformed reference. [store]'s
  /// previous ordering built the (unvalidated) companion straight from
  /// [newLabel], inserted it unconditionally, and only validated afterwards
  /// to build the return value — so a caller told "store failed" (the
  /// thrown exception, caught by `StoreLabelUsecase`) had in fact already
  /// had its row persisted. That silent write-on-"failure" is exactly how
  /// the payjoin receiver's exposed-UTXO labels ended up in the table
  /// despite every one of those calls logging "Failed to store label".
  void _validateOrThrow(NewLabel newLabel) {
    LabelEntity(
      id: -1, // The row doesn't exist yet; the real id comes from insert().
      type: newLabel.type,
      label: newLabel.label,
      reference: newLabel.reference,
      origin: newLabel.origin,
    );
  }

  @override
  Future<void> trash(int id) async {
    await _database.managers.labels.filter((l) => l.id(id)).delete();
  }

  @override
  Future<List<LabelEntity>> fetchAll() async {
    final rows = await _database.managers.labels.get();
    return _mapRowsTolerantly(rows);
  }

  /// Maps each row independently instead of eagerly via `.map().toList()`:
  /// a single row whose reference doesn't pass [LabelEntity]'s validation
  /// (e.g. a row written before validate-before-write was enforced above,
  /// or the fallout of any other now-fixed write-path bug — legacy data
  /// this can't retroactively repair) must not poison the whole batch. All
  /// three read paths funnel through here, so a single corrupt row cannot
  /// mysteriously blank out a wallet's entire transaction list — its own
  /// label is simply dropped from the result and warning-logged.
  List<LabelEntity> _mapRowsTolerantly(List<LabelRow> rows) {
    final entities = <LabelEntity>[];
    for (final row in rows) {
      try {
        entities.add(LabelMapper.toLabelEntity(row));
      } catch (e) {
        log.warning('Skipping corrupt label row ${row.id}: $e');
      }
    }
    return entities;
  }
}
