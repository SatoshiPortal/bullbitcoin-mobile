import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedDatasource extends Mock implements SeedDatasource {}

void main() {
  setUpAll(() => registerFallbackValue(SeedModel.bytes(bytes: [0])));

  final words = [...List.filled(11, 'abandon'), 'about'];

  test(
    'canonical ownership stores the parent without its passphrase',
    () async {
      final source = _MockSeedDatasource();
      final parent = SeedModel.mnemonic(mnemonicWords: words);
      final protected = SeedModel.mnemonic(
        mnemonicWords: words,
        passphrase: 'synthetic-vault-passphrase',
      );
      when(
        () => source.exists(parent.masterFingerprint),
      ).thenAnswer((_) async => false);
      when(
        () => source.store(
          fingerprint: parent.masterFingerprint,
          seed: any(named: 'seed'),
        ),
      ).thenAnswer((_) async {});

      final fingerprint = await SeedRepository(
        source: source,
      ).ensureCanonicalSeed(protected.toEntity());

      expect(fingerprint, parent.masterFingerprint);
      expect(fingerprint, isNot(protected.masterFingerprint));
      final stored =
          verify(
                () => source.store(
                  fingerprint: parent.masterFingerprint,
                  seed: captureAny(named: 'seed'),
                ),
              ).captured.single
              as MnemonicSeedModel;
      expect(stored.mnemonicWords, words);
      expect(stored.passphrase, isNull);
      expect(stored.bytes, parent.bytes);
      verifyNever(
        () => source.store(
          fingerprint: protected.masterFingerprint,
          seed: any(named: 'seed'),
        ),
      );
    },
  );

  for (final matching in [true, false]) {
    test(
      'canonical owner validates full stored seed (matching: $matching)',
      () async {
        final source = _MockSeedDatasource();
        final parent = SeedModel.mnemonic(mnemonicWords: words);
        final protected = SeedModel.mnemonic(
          mnemonicWords: words,
          passphrase: 'synthetic-vault-passphrase',
        );
        when(
          () => source.exists(parent.masterFingerprint),
        ).thenAnswer((_) async => true);
        when(() => source.get(parent.masterFingerprint)).thenAnswer(
          (_) async =>
              matching ? parent : SeedModel.bytes(bytes: List.filled(32, 7)),
        );

        final result = SeedRepository(
          source: source,
        ).ensureCanonicalSeed(protected.toEntity());

        if (matching) {
          expect(await result, parent.masterFingerprint);
        } else {
          await expectLater(result, throwsFormatException);
        }
        verifyNever(
          () => source.store(
            fingerprint: any(named: 'fingerprint'),
            seed: any(named: 'seed'),
          ),
        );
      },
    );
  }

  test('matches an account xpub to the stored seed', () async {
    final source = _MockSeedDatasource();
    final seedBytes = Uint8List.fromList(
      List<int>.generate(32, (index) => index + 1),
    );
    final model = SeedModel.bytes(bytes: seedBytes);
    final fingerprint = model.masterFingerprint;
    final accountXpub = (await Bip32Derivation.getAccountXpub(
      seedBytes: seedBytes,
      scriptType: ScriptType.bip84,
      network: Network.bitcoinMainnet,
    )).toBase58();
    when(() => source.exists(fingerprint)).thenAnswer((_) async => true);
    when(() => source.get(fingerprint)).thenAnswer((_) async => model);

    final repository = SeedRepository(source: source);

    expect(
      await repository.matchesXpubs(
        fingerprint: fingerprint,
        keys: [(derivationPath: "m/84'/0'/0'", xpub: accountXpub)],
      ),
      isTrue,
    );
    expect(
      await repository.matchesXpubs(
        fingerprint: fingerprint,
        keys: [(derivationPath: "m/84'/0'/1'", xpub: accountXpub)],
      ),
      isFalse,
    );
  });
}
