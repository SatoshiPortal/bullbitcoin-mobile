import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';
import 'package:labels/labels_table.dart';
import 'package:labels/labels_table.drift.dart';
import 'package:labels/src/data/label_row_mapper.dart';
import 'package:labels/src/domain/label_entity.dart';
import 'package:labels/src/domain/labels_repository_port.dart';
import 'package:labels/src/domain/new_label.dart';

import 'drift_labels_repository.drift.dart';

@DriftAccessor(tables: [LabelsTable])
class DriftLabelsRepository extends DatabaseAccessor<GeneratedDatabase>
    with $DriftLabelsRepositoryMixin
    implements LabelsRepositoryPort {
  DriftLabelsRepository({required GeneratedDatabase database})
    : super(database);

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
    final companion = LabelRowMapper.newLabelEntityToCompanion(normalized);
    final id = await into(labelsTable).insert(
      companion,
      onConflict: DoUpdate(
        (old) => companion,
        target: [labelsTable.label, labelsTable.reference],
      ),
    );

    return LabelEntity(
      id: id,
      type: normalized.type,
      label: normalized.label,
      reference: normalized.reference,
      origin: normalized.origin,
    );
  }

  @override
  Future<void> storeAll(List<NewLabel> newLabels) async {
    await transaction(() async {
      for (final label in newLabels) {
        await store(label);
      }
    });
  }

  @override
  Future<List<LabelEntity>> fetchByLabel(String label) async {
    final rows = await (select(
      labelsTable,
    )..where((row) => row.label.equals(label))).get();
    return _mapRowsTolerantly(rows);
  }

  @override
  Future<List<LabelEntity>> fetchByReference(String reference) async {
    final rows = await (select(
      labelsTable,
    )..where((row) => row.reference.equals(reference))).get();
    return _mapRowsTolerantly(rows);
  }

  @override
  Future<LabelEntity?> fetchById(int id) async {
    final row = await (select(
      labelsTable,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row != null ? LabelRowMapper.toLabelEntity(row) : null;
  }

  @override
  Future<void> trash(int id) async {
    await (delete(labelsTable)..where((row) => row.id.equals(id))).go();
  }

  @override
  Future<List<LabelEntity>> fetchAll() async {
    final rows = await select(labelsTable).get();
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
        entities.add(LabelRowMapper.toLabelEntity(row));
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
