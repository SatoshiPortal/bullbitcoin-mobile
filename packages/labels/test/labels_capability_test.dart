import 'package:labels/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';

import 'support/labels_test_database.dart';

void main() {
  late LabelsTestDatabase database;
  late Labels labels;

  setUp(() {
    database = LabelsTestDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    labels = createLabelsForTesting(
      database: database,
      listAttributedFreezes: () => fail('Unexpected freeze read'),
      freezeAttributedOutpoints: (_) => fail('Unexpected freeze'),
      openWallet: (_) async =>
          throw StateError('Wallet opening must remain lazy'),
    );
  });

  test('fetches matching labels and scopes suggestions by type', () async {
    const address = 'bc1qtest';
    final txid = 'a' * 64;
    expect(
      await labels.store(NewLabel.addr(address: address, label: 'lunch')),
      isA<Ok<Label, LabelFailure>>(),
    );
    expect(
      await labels.store(NewLabel.tx(transactionId: txid, label: 'private')),
      isA<Ok<Label, LabelFailure>>(),
    );

    final all = await labels.fetch();
    final matches = await labels.fetch(reference: address);
    final suggestions = await labels.suggestions(type: LabelType.address);
    expect((all as Ok<List<Label>, LabelFailure>).value, hasLength(2));
    expect(
      (matches as Ok<List<Label>, LabelFailure>).value.single.label,
      'lunch',
    );
    expect((suggestions as Ok<Set<String>, LabelFailure>).value, {'lunch'});
  });

  test('distinguishes empty reads from storage failure', () async {
    final empty = await labels.fetch(reference: 'bc1qmissing');
    expect((empty as Ok<List<Label>, LabelFailure>).value, isEmpty);

    await database.customStatement('DROP TABLE labels');

    expect(await labels.fetch(), isA<Err<List<Label>, LabelFailure>>());
    expect(
      await labels.fetch(reference: 'bc1qmissing'),
      isA<Err<List<Label>, LabelFailure>>(),
    );
    expect(await labels.suggestions(), isA<Err<Set<String>, LabelFailure>>());
    expect(
      await labels.exportLabels(LabelFormat.bip329),
      isA<Err<String, LabelFailure>>(),
    );
  });
}
