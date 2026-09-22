import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  late SqliteDatabase database;
  late GetIt registry;
  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    registry = GetIt.asNewInstance()
      ..registerSingleton<SqliteDatabase>(database);
    LabelsLocator.registerPorts(registry);
    LabelsLocator.registerFrameworks(registry);
    LabelsLocator.registerUseCases(registry);
    LabelsLocator.registerFacade(registry);
  });
  tearDown(() async {
    await registry.reset();
    await database.close();
  });
  test('backup reads fail when a stored label cannot be represented', () async {
    await database
        .into(database.labels)
        .insert(
          LabelsCompanion.insert(
            type: LabelTypeColumn.tx,
            label: 'Valid',
            reference: 'a' * 64,
          ),
        );
    await database
        .into(database.labels)
        .insert(
          LabelsCompanion.insert(
            type: LabelTypeColumn.tx,
            label: 'Corrupt',
            reference: 'broken-reference',
          ),
        );
    expect(await registry<LabelsFacade>().fetchAllForBackup(), isA<Err>());
    final tolerant = await registry<LabelsFacade>().fetchAllOrFailure();
    expect((tolerant as Ok<List<Label>, LabelFailure>).value, hasLength(1));
  });
  test('database failure is distinct from an empty strict read', () async {
    expect(
      (await registry<LabelsFacade>().fetchAllForBackup()
              as Ok<List<LabelEntity>, LabelFailure>)
          .value,
      isEmpty,
    );
    await database.customStatement('DROP TABLE labels');
    expect(await registry<LabelsFacade>().fetchAllForBackup(), isA<Err>());
  });
  test('owner notifications never expose rolled-back labels', () async {
    await database.select(database.labels).get();
    var updates = 0;
    final facade = registry<LabelsFacade>();
    final subscription = facade.watchChanges().listen((_) => updates++);
    addTearDown(subscription.cancel);
    expect(
      await facade.store(NewLabel.tx(transactionId: 'b' * 64, label: 'Saved')),
      isA<Ok>(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(updates, 1);
    await expectLater(
      database.transaction(() async {
        expect(
          await facade.store(
            NewLabel.tx(transactionId: 'c' * 64, label: 'Rolled back'),
          ),
          isA<Ok>(),
        );
        expect(updates, 1);
        throw Exception('rollback fixture');
      }),
      throwsException,
    );
    await Future<void>.delayed(Duration.zero);
    // Drift may invalidate a table after rollback; consumers reread facts.
    final afterRollback = updates;
    final labels =
        (await facade.fetchAllForBackup()
                as Ok<List<LabelEntity>, LabelFailure>)
            .value;
    expect(labels.single.label, 'Saved');
    expect(await facade.trash(labels.single.id), isA<Ok>());
    await Future<void>.delayed(Duration.zero);
    expect(updates, greaterThan(afterRollback));
  });
}
