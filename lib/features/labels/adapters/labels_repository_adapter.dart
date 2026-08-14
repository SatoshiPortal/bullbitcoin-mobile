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
      type: normalized.type,
      label: normalized.label,
      reference: normalized.reference,
      origin: normalized.origin,
    );
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
    await _database.managers.labels.filter((l) => l.id(id)).delete();
  }

  @override
  Future<List<LabelEntity>> fetchAll() async {
    final rows = await _database.managers.labels.get();
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
