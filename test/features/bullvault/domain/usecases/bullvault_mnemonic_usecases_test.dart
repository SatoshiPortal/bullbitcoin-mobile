import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/derive_bullvault_mnemonic_key_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/generate_bullvault_inheritance_mnemonic_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';

import '../../../../core_test/wallet/bdk_wallet_test_fixture.dart';

void main() {
  test('generates a valid 24-word inheritance mnemonic', () {
    const usecase = GenerateBullVaultInheritanceMnemonicUsecase();

    final result = usecase.execute();

    final words = (result as Ok<List<String>, BullVaultFailure>).value;
    expect(words, hasLength(24));
    expect(() => bip39.Mnemonic.fromWords(words: words), returnsNormally);
  });

  test('derives the inheritance BIP48 account for the selected network', () {
    const usecase = DeriveBullVaultMnemonicKeyUsecase();
    final words = testMnemonics.first.split(' ');

    final testnet = usecase.execute(
      words: words,
      network: Network.bitcoinTestnet,
    );
    final mainnet = usecase.execute(
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
  });
}
