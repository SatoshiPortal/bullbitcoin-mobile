// Behavioral proof for the audit finding on the BIP85 derive-next use cases
// (issue #2645 fix).
//
// `fix(bip85)` passes a hardcoded `Environment.mainnet` to `getWallets`, so a
// wallet running on testnet finds no default wallet at all and derivation
// fails instead of using the active-environment default.
import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBip85Repository extends Mock implements Bip85Repository {}

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

void main() {
  late _MockBip85Repository bip85Repository;
  late _MockGetDefaultSeedUsecase getDefaultSeed;
  late _MockGetSettingsUsecase getSettings;

  final seed = MnemonicSeed(
    mnemonicWords: const [
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'abandon',
      'about',
    ],
    bytes: Uint8List.fromList(List<int>.filled(32, 7)),
    masterFingerprint: 'aabbccdd',
  );

  setUpAll(() {
    registerFallbackValue(Bip85Application.bip39);
    registerFallbackValue(bip39.MnemonicLength.words12);
  });

  setUp(() {
    bip85Repository = _MockBip85Repository();
    getDefaultSeed = _MockGetDefaultSeedUsecase();
    getSettings = _MockGetSettingsUsecase();

    // The app is running on testnet.
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );

    when(
      () => getDefaultSeed.execute(environment: Environment.testnet),
    ).thenAnswer((_) async => Ok<Seed, SeedFailure>(seed));
    when(
      () => bip85Repository.fetchNextIndexForApplication(any()),
    ).thenAnswer((_) async => const Ok(0));
    when(
      () => bip85Repository.deriveMnemonic(
        xprvBase58: any(named: 'xprvBase58'),
        length: any(named: 'length'),
        index: any(named: 'index'),
        alias: any(named: 'alias'),
      ),
    ).thenAnswer(
      (_) async => Ok((
        derivation: "83696968'/39'/0'/12'/0'",
        mnemonic: bip39.Mnemonic.fromWords(
          words: const [
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'about',
          ],
        ),
      )),
    );
    when(
      () => bip85Repository.deriveHex(
        xprvBase58: any(named: 'xprvBase58'),
        length: any(named: 'length'),
        index: any(named: 'index'),
        alias: any(named: 'alias'),
      ),
    ).thenAnswer(
      (_) async =>
          const Ok((derivation: "83696968'/128169'/30'/0'", hex: 'ab')),
    );
  });

  test(
    'mnemonic derivation uses the active-environment default wallet',
    () async {
      final usecase = DeriveNextBip85MnemonicFromDefaultWalletUsecase(
        bip85Repository: bip85Repository,
        getDefaultSeedUsecase: getDefaultSeed,
        getSettingsUsecase: getSettings,
      );

      final result = await usecase.execute();

      expect(
        result,
        isA<Ok<({String derivation, bip39.Mnemonic mnemonic}), Bip85Failure>>(),
        reason: 'a testnet default wallet must be usable for BIP85 derivation',
      );
    },
  );

  test('hex derivation uses the active-environment default wallet', () async {
    final usecase = DeriveNextBip85HexFromDefaultWalletUsecase(
      bip85Repository: bip85Repository,
      getDefaultSeedUsecase: getDefaultSeed,
      getSettingsUsecase: getSettings,
    );

    final result = await usecase.execute(length: 30);

    expect(
      result,
      isA<Ok<({String derivation, String hex}), Bip85Failure>>(),
      reason: 'a testnet default wallet must be usable for BIP85 derivation',
    );
  });
}
