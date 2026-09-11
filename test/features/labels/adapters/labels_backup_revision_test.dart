import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/labels/adapters/labels_repository_adapter.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase database;
  late DriftLabelsRepositoryAdapter repository;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    repository = DriftLabelsRepositoryAdapter(database: database);
  });

  tearDown(() => database.close());

  Future<int> revision() async =>
      (await database.select(database.walletBackupStates).getSingleOrNull())
          ?.localRevision ??
      0;

  NewLabel label({String? origin}) => NewLabel(
    type: LabelType.transaction,
    reference: 'a' * 64,
    label: 'retirement',
    origin: origin,
  );

  test(
    'writes remain dirty without a notifier or active backup runner',
    () async {
      final stored = await repository.store(label());
      expect(await revision(), 1);

      await repository.store(label());
      expect(
        await revision(),
        1,
        reason: 'an unchanged label is not a mutation',
      );

      await repository.store(label(origin: 'wallet'));
      expect(await revision(), 2);
      expect((await repository.fetchAll()).single.origin, 'wallet');

      await repository.trash(stored.id);
      expect(await revision(), 3);
      await repository.trash(stored.id);
      expect(await revision(), 3);
      expect(await repository.fetchAll(), isEmpty);
    },
  );

  test('failed revision recording rolls back label storage', () async {
    await database.customStatement('''
      CREATE TRIGGER reject_label_backup_revision
      BEFORE UPDATE OF local_revision ON wallet_backup_states
      BEGIN SELECT RAISE(ABORT, 'injected revision failure'); END
    ''');
    await expectLater(repository.store(label()), throwsA(isA<Exception>()));
    expect(await repository.fetchAll(), isEmpty);
    expect(await revision(), 0);
  });

  test(
    'upserting a label returns its own row, not the last inserted row',
    () async {
      final first = await repository.store(label());
      final second = await repository.store(
        NewLabel(
          type: LabelType.transaction,
          reference: 'b' * 64,
          label: 'another transaction',
        ),
      );
      final updated = await repository.store(label(origin: 'wallet'));
      expect(updated.id, first.id);
      expect(updated.id, isNot(second.id));
      expect(updated.origin, 'wallet');
    },
  );

  test('a committed edit stays dirty after reopening the database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bbm-label-backup-',
    );
    final file = File('${directory.path}/backup.sqlite');
    var disk = SqliteDatabase(NativeDatabase(file));
    try {
      final writer = DriftLabelsRepositoryAdapter(database: disk);
      await writer.store(label());
      await disk.customStatement(
        'UPDATE wallet_backup_states SET uploaded_revision = local_revision',
      );
      await writer.store(label(origin: 'edited before termination'));
      await disk.close();
      disk = SqliteDatabase(NativeDatabase(file));

      final checkpoint = await disk.select(disk.walletBackupStates).getSingle();
      expect(checkpoint.localRevision, 2);
      expect(checkpoint.uploadedRevision, 1);
      expect(
        (await DriftLabelsRepositoryAdapter(
          database: disk,
        ).fetchAll()).single.origin,
        'edited before termination',
      );
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
    }
  });

  test('failed revision recording rolls back label deletion', () async {
    final stored = await repository.store(label());
    final before = await revision();
    await database.customStatement('''
      CREATE TRIGGER reject_label_backup_revision
      BEFORE UPDATE OF local_revision ON wallet_backup_states
      BEGIN SELECT RAISE(ABORT, 'injected revision failure'); END
    ''');
    await expectLater(repository.trash(stored.id), throwsA(isA<Exception>()));
    expect((await repository.fetchAll()).single.label, 'retirement');
    expect(await revision(), before);
  });

  test('invalid batch rolls back both labels and backup revisions', () async {
    await expectLater(
      repository.storeAll([
        label(),
        NewLabel(
          type: LabelType.transaction,
          reference: 'invalid',
          label: 'bad',
        ),
      ]),
      throwsA(isA<Exception>()),
    );
    expect(await repository.fetchAll(), isEmpty);
    expect(await revision(), 0);
  });
}
