import 'dart:convert';

import 'package:labels/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show FrozenOutpoint, SyncStorageFailure;

import 'support/labels_test_database.dart';

void main() {
  late LabelsTestDatabase database;
  late Labels labels;
  late List<FrozenOutpoint> frozen;
  late bool readable;

  setUp(() {
    database = LabelsTestDatabase(NativeDatabase.memory());
    frozen = [];
    readable = true;
    addTearDown(database.close);
    labels = createLabelsForTesting(
      database: database,
      listAttributedFreezes: () async =>
          readable ? Ok(frozen) : const Err(SyncStorageFailure()),
      freezeAttributedOutpoints: (_) => fail('Unexpected freeze'),
      openWallet: (_) async =>
          throw StateError('Wallet opening must remain lazy'),
    );
  });

  test('BIP329 export keeps all attributions for the same output', () async {
    final point = (txId: 'a' * 64, vout: 0);
    const first = '[0f36572d/84h/1h/0h]';
    const second = '[12345678/84h/1h/0h]';
    frozen.addAll([
      FrozenOutpoint(point, origin: 'wpkh($first)'),
      FrozenOutpoint(point, origin: 'wpkh($second)'),
      FrozenOutpoint(point, origin: ''),
    ]);
    final result = await labels.exportLabels(LabelFormat.bip329);
    final jsonl = (result as Ok<String, LabelFailure>).value;
    final rows = const LineSplitter()
        .convert(jsonl)
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();
    expect(rows.map((row) => row['origin']), [first, second, null]);
    expect(rows.map((row) => row['ref']), List.filled(3, '${point.txId}:0'));
    expect(rows.map((row) => row['spendable']), [false, false, false]);

    // Ordinary user import must never apply these freeze records.
    expect(await labels.importLabels(jsonl, LabelFormat.bip329), isA<Ok>());
    readable = false;
    expect(await labels.exportLabels(LabelFormat.bip329), isA<Err>());
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
