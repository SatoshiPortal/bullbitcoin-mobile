import 'package:secrets/bip85.dart';

import 'initialization_result.dart';

import 'dart:typed_data';

import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/default_wallets.dart';
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
  final registry = locator<Bip85Derivations>();
  final createDefaultWalletsUsecase = locator<DefaultWalletProvisioning>();

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

  late Fingerprint parent;

  Future<List<Bip85Derivation>> derivations() async {
    final result = await registry.list();
    expect(result, isA<Ok>());
    return (result as Ok<List<Bip85Derivation>, Failure>).value
        .where((record) => record.parentFingerprint == parent.hex)
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

  test('allocates and renders the same deterministic child across mnemonic lengths', () async {
    final start = await nextIndex();
    final root = bip32.Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed))
        .toBase58();
    final lengths = [
      bip39.MnemonicLength.words12,
      bip39.MnemonicLength.words24,
    ];
    for (final (offset, length) in lengths.indexed) {
      final index = start + offset;
      final reserved = await registry.deriveNextMnemonic(
        parent: parent,
        length: length,
        alias: 'Derivation ${offset + 1}',
      );
      expect(reserved, isA<Ok>());
      final record = (reserved as Ok<Bip85Derivation, SecretFailure>).value;
      expect(record.index, index);
      expect(record.path, "39'/0'/${length.words}'/$index'");
      expect(record.application, Bip85Application.bip39);
      final expected = bip85.Bip85Entropy.deriveMnemonic(
        xprvBase58: root,
        language: bip39.Language.english,
        length: length,
        index: index,
      );
      final revealed = await registry.reveal(parent);
      expect(revealed, isA<Ok>());
      final child =
          (revealed
                  as Ok<
                    List<({Bip85Derivation derivation, String entropy})>,
                    SecretFailure
                  >)
              .value
              .singleWhere((child) => child.derivation.path == record.path);
      expect(child.derivation.alias, record.alias);
      expect(child.entropy == expected.sentence, isTrue);
    }
  });
}
