import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Public master key from the official BIP85 test vectors.
const _masterXprv =
    'xprv9s21ZrQH143K2LBWUUQRFXhucrQqBpKdRRxNVq2zBqsx8HVqFk2uYo8kmbaLLHRdqtQpUm98uKfu3vca1LqdGhUtyoFnCNkfmXRyPXLjbKb';

/// Public, unrelated BIP85 vector key used to model a replaced default seed.
const _otherXprv =
    'xprv9s21ZrQH143K2srSbCSg4m4kLvPMzcWydgmKEnMmoZUurYuBuYG46c6P71UGXMzmriLzCCBvKQWBUv3vPB3m1SATMhp3uEjXHJ42jFg7myX';

void main() {
  late SqliteDatabase database;
  late Bip85Datasource datasource;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    datasource = Bip85Datasource(sqlite: database);
  });

  tearDown(() => database.close());

  test('replaces a stored row from a stale root fingerprint', () async {
    final stale = await datasource.deriveMnemonic(
      xprvBase58: _otherXprv,
      length: bip39.MnemonicLength.words12,
      index: 0,
      alias: 'Old',
    );

    final replaced = await datasource.deriveMnemonic(
      xprvBase58: _masterXprv,
      length: bip39.MnemonicLength.words12,
      index: 0,
      alias: 'New',
    );

    expect(replaced.derivation, stale.derivation);
    expect(replaced.mnemonic.sentence, isNot(stale.mnemonic.sentence));
    final row = await datasource.fetch(replaced.derivation);
    expect(row, isNotNull);
    expect(row!.alias, 'New');
  });

  test('rejects a duplicate insert for the same root fingerprint', () async {
    await datasource.deriveMnemonic(
      xprvBase58: _masterXprv,
      length: bip39.MnemonicLength.words12,
      index: 0,
      alias: 'Reserved',
    );

    expect(
      () => datasource.deriveMnemonic(
        xprvBase58: _masterXprv,
        length: bip39.MnemonicLength.words12,
        index: 0,
        alias: 'Reserved',
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('next-index allocation skips every caller-supplied exclusion', () async {
    await datasource.deriveMnemonic(
      xprvBase58: _masterXprv,
      length: bip39.MnemonicLength.words12,
      index: 99,
      alias: 'Before reserved range',
    );

    expect(
      await datasource.fetchNextIndexForApplication(
        Bip85ApplicationColumn.bip39,
      ),
      100,
    );
    expect(
      await datasource.fetchNextIndexForApplication(
        Bip85ApplicationColumn.bip39,
        excludedIndices: const {100, 101},
      ),
      102,
    );
  });

  group('official BIP85 application 39 vectors', () {
    test('derives and stores the 12-word English vector at index 0', () async {
      final result = await datasource.deriveMnemonic(
        xprvBase58: _masterXprv,
        length: bip39.MnemonicLength.words12,
        index: 0,
        alias: 'Vector',
      );

      expect(
        result.mnemonic.sentence,
        'girl mad pet galaxy egg matter matrix prison refuse sense ordinary '
        'nose',
      );
      expect(result.derivation, "39'/0'/12'/0'");
      final stored = await datasource.fetch(result.derivation);
      expect(stored?.path, result.derivation);
      expect(stored?.index, 0);
    });

    test('previews the 12-word vector without storing it', () async {
      final preview = await datasource.deriveMnemonicPreview(
        xprvBase58: _masterXprv,
        length: bip39.MnemonicLength.words12,
        index: 0,
      );

      expect(
        preview.mnemonic.sentence,
        'girl mad pet galaxy egg matter matrix prison refuse sense ordinary '
        'nose',
      );
      expect(preview.derivation, "39'/0'/12'/0'");
      expect(await datasource.fetch(preview.derivation), isNull);
    });

    test('previews the 18-word English vector at index 0', () async {
      final preview = await datasource.deriveMnemonicPreview(
        xprvBase58: _masterXprv,
        length: bip39.MnemonicLength.words18,
        index: 0,
      );

      expect(
        preview.mnemonic.sentence,
        'near account window bike charge season chef number sketch tomorrow '
        'excuse sniff circle vital hockey outdoor supply token',
      );
      expect(preview.derivation, "39'/0'/18'/0'");
    });

    test('previews the 24-word English vector at index 0', () async {
      final preview = await datasource.deriveMnemonicPreview(
        xprvBase58: _masterXprv,
        length: bip39.MnemonicLength.words24,
        index: 0,
      );

      expect(
        preview.mnemonic.sentence,
        'puppy ocean match cereal symbol another shed magic wrap hammer bulb '
        'intact gadget divorce twin tonight reason outdoor destroy simple '
        'truth cigar social volcano',
      );
      expect(preview.derivation, "39'/0'/24'/0'");
    });
  });
}
