import 'dart:typed_data';

import 'package:bb_mobile/core/bip85_derivations/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85_derivations/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85_derivations/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bip85/bip85.dart' as bip85;
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final sqlite = locator<SqliteDatabase>();
  final seedRepository = locator<SeedRepository>();
  final walletRepository = locator<WalletRepository>();
  final bip85Datasource = locator<Bip85Datasource>();
  final bip85Repository = locator<Bip85Repository>();
  final createDefaultWalletsUsecase = locator<CreateDefaultWalletsUsecase>();

  final mnemonic = Mnemonic.fromWords(
    words: [
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'wrong',
    ],
  );

  final usecase = DeriveNextBip85MnemonicFromDefaultWalletUsecase(
    bip85Repository: bip85Repository,
    walletRepository: walletRepository,
    seedRepository: seedRepository,
  );

  setUpAll(() async {
    // Clear all relevant tables before each test
    await sqlite.managers.bip85Derivations.delete();
    await sqlite.managers.walletMetadatas.delete();

    await createDefaultWalletsUsecase.execute(mnemonicWords: mnemonic.words);
  });

  setUp(() async {
    await sqlite.managers.bip85Derivations.delete();
  });

  group(
    'DeriveNextBip85MnemonicFromDefaultWalletUsecase Integration Tests',
    () {
      test('one derivation with index 0 with empty table', () async {
        const length = bip39.MnemonicLength.words12;
        const index = 0;

        // Execute the usecase
        final result = await usecase.execute(length: length, alias: 'test');

        // Verify the derivation path
        expect(result.derivation, contains("m/83696968'/39'/0'/12'/0'"));
        expect(result.mnemonic, isA<bip39.Mnemonic>());
        expect(result.mnemonic.length, equals(length));

        // Verify the derivation was stored in the database
        final storedDerivations = await bip85Datasource.fetchAll();
        expect(storedDerivations.length, 1);

        // Ensure index 0, alias and application are correct
        final firstDerivation = storedDerivations.first;
        expect(firstDerivation.index, index);
        expect(firstDerivation.alias, 'test');
        expect(firstDerivation.application, Bip85ApplicationColumn.bip39);

        // Get the xprv from the seed
        final xprv = Bip32Derivation.getXprvFromSeed(
          Uint8List.fromList(mnemonic.seed),
          Network.bitcoinTestnet,
        );

        // Now generate the same derivation using BIP85 library directly
        final directBip85Mnemonic = bip85.toMnemonic(
          xprv: xprv,
          wordCount: length.words,
          index: index,
        );

        // Verify both results are identical
        expect(result.mnemonic.sentence, equals(directBip85Mnemonic));
      });

      test('Two derivations with index bump and different lengths', () async {
        // Execute the usecase first time
        final a = await usecase.execute(
          length: bip39.MnemonicLength.words12,
          alias: 'First derivation',
        );

        // Execute the usecase second time
        final b = await usecase.execute(
          length: bip39.MnemonicLength.words24,
          alias: 'Second derivation',
        );

        // Get the xprv from the seed
        final xprv = Bip32Derivation.getXprvFromSeed(
          Uint8List.fromList(mnemonic.seed),
          Network.bitcoinTestnet,
        );

        // Verify database has both derivations stored
        final storedDerivations = await bip85Datasource.fetchAll();
        expect(storedDerivations.length, equals(2));

        final indices = storedDerivations.map((d) => d.index).toList()..sort();
        expect(indices, equals([0, 1]));

        // Verify aliases are stored correctly
        final first = storedDerivations.firstWhere((d) => d.index == 0);
        expect(first.derivation, "m/83696968'/39'/0'/12'/0'");
        expect(first.index, 0);
        expect(first.alias, 'First derivation');
        expect(first.application, equals(Bip85ApplicationColumn.bip39));
        expect(
          a.mnemonic.sentence,
          bip85.toMnemonic(xprv: xprv, wordCount: 12, index: 0),
        );

        final second = storedDerivations.firstWhere((d) => d.index == 1);
        expect(second.derivation, "m/83696968'/39'/0'/24'/1'");
        expect(second.index, 1);
        expect(second.alias, 'Second derivation');
        expect(second.application, equals(Bip85ApplicationColumn.bip39));
        expect(
          b.mnemonic.sentence,
          bip85.toMnemonic(xprv: xprv, wordCount: 24, index: 1),
        );
      });
    },
  );
}
