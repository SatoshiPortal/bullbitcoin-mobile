import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/features/labels/adapters/labels_repository_adapter.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteDatabase db;
  late DriftLabelsRepositoryAdapter adapter;

  const validTxid =
      '5f1fabc488e1df397e90114374277f2edfa7613fec96769f22d7aa828142709c';
  const otherTxid =
      'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    adapter = DriftLabelsRepositoryAdapter(database: db);
  });

  tearDown(() async => db.close());

  /// Inserts a row directly via the raw table, bypassing every app-level
  /// validation — simulates a legacy row that predates validate-before-write
  /// (or any other now-fixed write-path bug), which the adapter's read paths
  /// must tolerate without throwing.
  Future<void> insertRawRow({
    required String label,
    required String reference,
    required LabelTypeColumn type,
  }) async {
    await db
        .into(db.labels)
        .insert(
          LabelsCompanion.insert(
            label: label,
            reference: reference,
            type: type,
          ),
        );
  }

  group('DriftLabelsRepositoryAdapter.store', () {
    test('persists a well-formed output label and returns it', () async {
      final stored = await adapter.store(
        NewLabel(
          type: LabelType.output,
          label: 'payjoin',
          reference: '$validTxid:0',
        ),
      );
      expect(stored.reference, '$validTxid:0');

      final fetched = await adapter.fetchByReference('$validTxid:0');
      expect(fetched, hasLength(1));
    });

    // Regression: store() used to build the DB companion straight from the
    // unvalidated NewLabel, insert it unconditionally, and only construct
    // (and thus validate) a LabelEntity afterwards to build the return
    // value — so a malformed reference was persisted to the DB even though
    // store() threw and the caller was told the write had failed.
    test('rejects a malformed reference WITHOUT persisting anything', () async {
      await expectLater(
        adapter.store(
          NewLabel(
            type: LabelType.output,
            label: 'payjoin',
            reference: 'not-a-txid:0',
          ),
        ),
        throwsA(isA<LabelValidationException>()),
      );

      final all = await adapter.fetchAll();
      expect(all, isEmpty);
    });
  });

  group('DriftLabelsRepositoryAdapter reads tolerate a corrupt row', () {
    setUp(() async {
      // A row that could never have been written by the fixed store() path,
      // simulating data left over from before that fix (or any other
      // now-resolved write-path bug) — reads must survive its presence.
      await insertRawRow(
        label: 'payjoin',
        reference: 'totally-corrupt',
        type: LabelTypeColumn.output,
      );
      await adapter.store(
        NewLabel(
          type: LabelType.output,
          label: 'payjoin',
          reference: '$validTxid:0',
        ),
      );
      await adapter.store(
        NewLabel(
          type: LabelType.transaction,
          label: 'payjoin',
          reference: otherTxid,
        ),
      );
    });

    test(
      'fetchAll returns every valid row and drops the corrupt one',
      () async {
        final all = await adapter.fetchAll();
        expect(all, hasLength(2));
        expect(
          all.map((l) => l.reference),
          containsAll(['$validTxid:0', otherTxid]),
        );
      },
    );

    test(
      'fetchByLabel returns every valid row and drops the corrupt one',
      () async {
        final byLabel = await adapter.fetchByLabel('payjoin');
        expect(byLabel, hasLength(2));
      },
    );

    test(
      'fetchByReference for a valid reference is unaffected by an unrelated corrupt row',
      () async {
        final byRef = await adapter.fetchByReference('$validTxid:0');
        expect(byRef, hasLength(1));
        expect(byRef.single.type, LabelType.output);
      },
    );

    test(
      'fetchById returns null for a corrupt row instead of throwing',
      () async {
        final corruptRow = await (db.select(
          db.labels,
        )..where((l) => l.reference.equals('totally-corrupt'))).getSingle();

        final fetched = await adapter.fetchById(corruptRow.id);
        expect(fetched, isNull);
      },
    );
  });
}
