import 'package:bb_mobile/features/bip85_entropy/domain/with_default_bip85_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/public/bip85_bindings.dart';

import 'initialization_result.dart';

import 'dart:typed_data';

import 'package:bb_mobile/features/bip85_entropy/data/bip85_repository.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/bip85_derivation_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/init.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) {
    requireSuccessfulBullInitialization(await Bull.init());
  }

  final secrets = locator<Secrets>();
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
    secrets: secrets,
  );

  final withDefault = WithDefaultBip85WalletUsecase(
    WalletBip85Bindings.reader(locator),
  );

  late Fingerprint parent;

  Future<List<Bip85DerivationEntity>> derivations() async {
    final result = await bip85Repository.fetchAll();
    expect(result, isA<Ok>());
    return (result as Ok<List<Bip85DerivationEntity>, Failure>).value
        .where((record) => record.xprvFingerprint == parent.hex)
        .toList();
  }

  Future<int> nextIndex() async {
    final indices = (await derivations())
        .where((record) => record.application == Bip85Application.bip39)
        .map((record) => record.index);
    return indices.fold<int>(
      0,
      (next, index) => index >= next ? index + 1 : next,
    );
  }

  setUpAll(() async {
    final imported = await secrets.import(
      words: mnemonic.words,
      language: Language.english,
    );
    final Secret secret;
    switch (imported) {
      case Ok(:final value):
        secret = value;
      case Err(failure: SecretAlreadyExistsFailure(:final id)):
        secret = switch (await secrets.fetch(id)) {
          Ok(:final value) => value,
          Err(:final failure) => fail('fetch failed: ${failure.runtimeType}'),
        };
      case Err(:final failure):
        fail('import failed: ${failure.runtimeType}');
    }
    parent = secret.id;
    expect(
      await createDefaultWalletsUsecase.execute(secret: secret),
      isA<Ok>(),
    );
  });

  group(
    'DeriveNextBip85MnemonicFromDefaultWalletUsecase Integration Tests',
    () {
      test('reserves and derives the next available index', () async {
        const length = bip39.MnemonicLength.words12;
        final index = await nextIndex();

        // Execute the usecase
        final result = await withDefault.execute(
          (fingerprint) => usecase.execute(
            fingerprint: fingerprint,
            length: length,
            alias: 'test',
          ),
        );
        expect(result, isA<Ok>());
        final (:derivation, mnemonic: resultMnemonic) = (result as Ok).value;

        // Verify the derivation path
        expect(derivation, "39'/0'/12'/$index'");
        expect(resultMnemonic, isA<bip39.Mnemonic>());
        expect(resultMnemonic.length, equals(length));

        // Verify the derivation was stored in the database
        final firstDerivation = (await derivations()).singleWhere(
          (record) => record.path == derivation,
        );
        expect(firstDerivation.index, index);
        expect(firstDerivation.alias, 'test');
        expect(firstDerivation.application, Bip85Application.bip39);

        // Get the xprv from the default-wallet seed (the outer `mnemonic`),
        // i.e. the same seed the usecase derives from — NOT the derived result.
        final xprv = bip32.Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed))
            .toBase58();

        // Now generate the same derivation using BIP85 library directly
        final directBip85Mnemonic = bip85.Bip85Entropy.deriveMnemonic(
          xprvBase58: xprv,
          language: bip39.Language.english,
          length: length,
          index: index,
        );

        // Verify both results are identical
        expect(resultMnemonic.sentence, directBip85Mnemonic.sentence);
      });

      test('advances the index across different mnemonic lengths', () async {
        final start = await nextIndex();
        // Execute the usecase first time
        final aResult = await withDefault.execute(
          (fingerprint) => usecase.execute(
            fingerprint: fingerprint,
            length: bip39.MnemonicLength.words12,
            alias: 'First derivation',
          ),
        );
        expect(aResult, isA<Ok>());
        final (derivation: aPath, mnemonic: aMnemonic) = (aResult as Ok).value;

        // Execute the usecase second time
        final bResult = await withDefault.execute(
          (fingerprint) => usecase.execute(
            fingerprint: fingerprint,
            length: bip39.MnemonicLength.words24,
            alias: 'Second derivation',
          ),
        );
        expect(bResult, isA<Ok>());
        final (derivation: bPath, mnemonic: bMnemonic) = (bResult as Ok).value;

        // Get the xprv from the seed
        final xprv = bip32.Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed))
            .toBase58();

        final storedDerivations = await derivations();
        final first = storedDerivations.singleWhere((d) => d.path == aPath);
        expect(first.path, "39'/0'/12'/$start'");
        expect(first.index, start);
        expect(first.alias, 'First derivation');
        expect(first.application, equals(Bip85Application.bip39));
        expect(
          aMnemonic.sentence,
          bip85.Bip85Entropy.deriveMnemonic(
            xprvBase58: xprv,
            language: bip39.Language.english,
            length: bip39.MnemonicLength.words12,
            index: start,
          ).sentence,
        );

        final second = storedDerivations.singleWhere((d) => d.path == bPath);
        final following = start + 1;
        expect(second.path, "39'/0'/24'/$following'");
        expect(second.index, following);
        expect(second.alias, 'Second derivation');
        expect(second.application, equals(Bip85Application.bip39));
        expect(
          bMnemonic.sentence,
          bip85.Bip85Entropy.deriveMnemonic(
            xprvBase58: xprv,
            language: bip39.Language.english,
            length: bip39.MnemonicLength.words24,
            index: following,
          ).sentence,
        );
      });
    },
  );
}
