import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/features/labels/adapters/labels_repository_adapter.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase db;
  late DriftLabelsRepositoryAdapter adapter;

  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    adapter = DriftLabelsRepositoryAdapter(database: db);
  });

  tearDown(() async => db.close());

  group('store', () {
    test('never persists a row when the label fails validation', () async {
      // A transaction reference must be 64 hex chars — this one isn't.
      await expectLater(
        () => adapter.store(
          NewLabel(
            type: LabelType.transaction,
            label: 'test',
            reference: 'too-short',
          ),
        ),
        throwsA(isA<LabelValidationException>()),
      );

      final rows = await db.select(db.labels).get();
      expect(
        rows,
        isEmpty,
        reason:
            'a rejected store must never reach the DB — validating before '
            'the insert is the whole point of this fix',
      );
    });

    test('persists a valid label and returns it with its id', () async {
      final stored = await adapter.store(
        NewLabel(
          type: LabelType.transaction,
          label: 'payjoin',
          reference: 'a' * 64,
        ),
      );

      expect(stored.id, greaterThan(0));
      final rows = await db.select(db.labels).get();
      expect(rows, hasLength(1));
    });
  });

  group('fetchAll / fetchByReference tolerate a corrupt row', () {
    test('a single corrupt row is skipped and logged, not letting it discard '
        'every valid label in the same query', () async {
      // Insert one valid row through the adapter (validated).
      await adapter.store(
        NewLabel(
          type: LabelType.transaction,
          label: 'payjoin',
          reference: 'a' * 64,
        ),
      );

      // Insert a corrupt row directly at the DB level, bypassing
      // LabelEntity's validation (simulates data that predates a
      // validation fix, or any other source of a malformed row).
      await db
          .into(db.labels)
          .insert(
            LabelsCompanion.insert(
              label: 'corrupt',
              reference: 'not-a-valid-64-char-txid',
              type: LabelTypeColumn.tx,
            ),
          );

      final all = await adapter.fetchAll();
      expect(
        all,
        hasLength(1),
        reason: 'the corrupt row must be dropped, not poison the whole batch',
      );
      expect(all.single.label, 'payjoin');

      final byReference = await adapter.fetchByReference('a' * 64);
      expect(byReference, hasLength(1));
    });
  });
}
