import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/derive_bullvault_mnemonic_key_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/generate_bullvault_inheritance_mnemonic_usecase.dart';
import 'package:secrets/secrets.dart' show EphemeralMnemonic, Language;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bb_mobile/features/bullvault/presentation/bullvault_inheritance_mnemonic_cubit.dart';
import '../../bullvault_secrets_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core_test/wallet/bdk_wallet_test_fixture.dart';

void main() {
  late BullVaultSecretsFixture fixture;
  setUp(() => fixture = BullVaultSecretsFixture());
  test('generates an independent unstored inheritance mnemonic', () async {
    final usecase = GenerateBullVaultInheritanceMnemonicUsecase(
      fixture.secrets,
    );

    final result = await usecase.execute();

    final mnemonic = (result as Ok<EphemeralMnemonic, BullVaultFailure>).value;
    expect(mnemonic.wordCount, 24);
    expect(fixture.storage.entries, isEmpty);
    final derive = DeriveBullVaultMnemonicKeyUsecase(fixture.secrets);
    expect(
      await derive.fromGenerated(
        mnemonic: mnemonic,
        network: Network.bitcoinTestnet,
      ),
      isA<Ok>(),
    );
    mnemonic.dispose();
    expect(
      await derive.fromGenerated(
        mnemonic: mnemonic,
        network: Network.bitcoinTestnet,
      ),
      isA<Err>(),
    );
    expect(fixture.storage.entries, isEmpty);
  });

  test(
    'derives the inheritance BIP48 account for the selected network',
    () async {
      final usecase = DeriveBullVaultMnemonicKeyUsecase(fixture.secrets);
      final words = testMnemonics.first.split(' ');

      final testnet = await usecase.execute(
        words: words,
        network: Network.bitcoinTestnet,
      );
      final mainnet = await usecase.execute(
        words: words,
        network: Network.bitcoinMainnet,
      );

      expect(
        (testnet as Ok<String, BullVaultFailure>).value,
        matches(RegExp(r"^\[[0-9a-f]{8}/48'/1'/0'/2'\]tpub")),
      );
      expect(
        (mainnet as Ok<String, BullVaultFailure>).value,
        matches(RegExp(r"^\[[0-9a-f]{8}/48'/0'/0'/2'\]xpub")),
      );
    },
  );
  test(
    'imports inheritance words in their selected language without storing them',
    () async {
      final words = bip39.Mnemonic(
        List.filled(16, 0),
        bip39.Language.spanish,
      ).words;
      final derive = DeriveBullVaultMnemonicKeyUsecase(fixture.secrets);
      final cubit = BullVaultInheritanceMnemonicCubit(
        GenerateBullVaultInheritanceMnemonicUsecase(fixture.secrets),
        derive,
      );
      final result = await cubit.import(
        words,
        Network.bitcoinTestnet,
        language: Language.spanish,
      );
      expect(
        (result as Ok<String, BullVaultFailure>).value,
        matches(RegExp(r"^\[[0-9a-f]{8}/48'/1'/0'/2'\]tpub")),
      );
      expect(
        await derive.execute(words: words, network: Network.bitcoinTestnet),
        isA<Err>(),
      );
      expect(fixture.storage.entries, isEmpty);
      await cubit.close();
    },
  );
}
