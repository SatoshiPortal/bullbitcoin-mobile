import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _DefaultSeed extends Mock implements GetDefaultSeedUsecase {}

void main() {
  late SqliteDatabase database;
  late Bip85Datasource datasource;
  late Bip85Repository repository;
  final seed = Seed.bytes(
    bytes: Uint8List.fromList(List.filled(32, 99)),
    masterFingerprint: 'fixture',
  );
  final root = Bip32Derivation.getXprvFromSeed(
    seed.bytes,
    Network.bitcoinMainnet,
  );
  final fingerprint = hex.encode(bip32.Bip32Keys.fromBase58(root).fingerprint);

  Future<void> store(
    String path, {
    Bip85ApplicationColumn application = Bip85ApplicationColumn.bip39,
    String? owner,
  }) => database
      .into(database.bip85Derivations)
      .insert(
        Bip85DerivationsCompanion.insert(
          path: path,
          xprvFingerprint: owner ?? fingerprint,
          application: application,
          status: Bip85StatusColumn.active,
          alias: const Value('Kept alias'),
        ),
      )
      .then((_) {});

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    datasource = Bip85Datasource(sqlite: database);
    repository = Bip85Repository(datasource: datasource);
  });
  tearDown(() => database.close());

  test(
    'allocation skips backup words without inserting a synthetic derivation',
    () async {
      await store("39'/0'/12'/99'");
      expect(
        (await repository.fetchNextIndexForApplication(Bip85Application.bip39)
                as Ok<int, Bip85Failure>)
            .value,
        101,
      );
      expect((await datasource.fetchAll()).map((row) => row.index), [99]);
    },
  );

  test(
    'explicit-index derivation rejects backup words before persistence',
    () async {
      await expectLater(
        datasource.deriveMnemonic(
          xprvBase58: root,
          length: bip39.MnemonicLength.words12,
          index: 100,
        ),
        throwsFormatException,
      );
      expect(await datasource.fetchAll(), isEmpty);
      expect(
        await repository.deriveMnemonic(
          xprvBase58: root,
          length: bip39.MnemonicLength.words12,
          index: 100,
        ),
        isA<Err<dynamic, Bip85Failure>>(),
      );
    },
  );

  test(
    'allocation preserves the same index for non-12-word requests',
    () async {
      await store("39'/0'/12'/99'");
      for (final length in [
        bip39.MnemonicLength.words18,
        bip39.MnemonicLength.words24,
      ]) {
        final result = await repository.fetchNextIndexForApplication(
          Bip85Application.bip39,
          mnemonicLength: length,
        );
        expect((result as Ok<int, Bip85Failure>).value, 100);
      }
      await store("128169'/32'/99'", application: Bip85ApplicationColumn.hex);
      expect(
        (await repository.fetchNextIndexForApplication(Bip85Application.hex)
                as Ok<int, Bip85Failure>)
            .value,
        100,
      );
    },
  );

  test(
    'the same index stays available for other lengths and applications',
    () async {
      final longer = await datasource.deriveMnemonic(
        xprvBase58: root,
        length: bip39.MnemonicLength.words24,
        index: 100,
        alias: 'Longer',
      );
      final hexadecimal = await datasource.deriveHex(
        xprvBase58: root,
        length: 32,
        index: 100,
      );
      expect(longer.derivation, "39'/0'/24'/100'");
      expect(hexadecimal.derivation, "128169'/32'/100'");
      expect((await datasource.fetch(longer.derivation))!.alias, 'Longer');
    },
  );

  test(
    'listing and export omit reserved and retired keys and preserve the root check',
    () async {
      for (final path in [
        "39'/0'/12'/100'",
        "m/83696968h/39h/0h/12h/100h",
        "128002'/100'/1'",
        "1642'/0'/1'",
        "1608'/0'/0'",
      ]) {
        await store(path);
      }
      await store("39'/0'/12'/99'");
      await store("39'/0'/24'/100'");
      await store("39'/0'/12'/101'", owner: 'another-root');
      final listing =
          (await repository.fetchAll()
                  as Ok<List<Bip85DerivationEntity>, Bip85Failure>)
              .value;
      expect(
        listing.map((row) => row.path),
        unorderedEquals([
          "39'/0'/12'/99'",
          "39'/0'/24'/100'",
          "39'/0'/12'/101'",
        ]),
      );
      final defaults = _DefaultSeed();
      when(() => defaults.execute()).thenAnswer((_) async => seed);
      final result = await FetchAllBip85DerivationsWithEntropyUsecase(
        bip85Repository: repository,
        getDefaultSeedUsecase: defaults,
      ).execute();
      final exported =
          (result
                  as Ok<
                    List<({Bip85DerivationEntity derivation, String entropy})>,
                    Bip85Failure
                  >)
              .value;
      expect(
        exported.map((row) => row.derivation.path),
        unorderedEquals(["39'/0'/12'/99'", "39'/0'/24'/100'"]),
      );
      expect(
        exported.every(
          (row) =>
              row.entropy.isNotEmpty && row.derivation.alias == 'Kept alias',
        ),
        isTrue,
      );
    },
  );

  test(
    'allocation reports exhaustion instead of returning a non-hardened index',
    () async {
      await store("39'/0'/12'/2147483647'");
      expect(
        await repository.fetchNextIndexForApplication(Bip85Application.bip39),
        isA<Err<int, Bip85Failure>>(),
      );
    },
  );
}
