import 'dart:typed_data';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

class DeriveBullVaultMnemonicKeyUsecase {
  const DeriveBullVaultMnemonicKeyUsecase();

  Result<String, BullVaultFailure> execute({
    required List<String> words,
    required Network network,
  }) {
    try {
      final mnemonic = bip39.Mnemonic.fromWords(words: words);
      final seed = Uint8List.fromList(mnemonic.seed);
      final fingerprint = bip32.Bip32Keys.fromSeed(seed).fingerprintHex;
      final path = Bip48Derivation.path(coinType: network.coinType, account: 0);
      final originPath = path.substring(2);
      final xpub = Bip32Derivation.deriveXpub(
        seedBytes: seed,
        derivationPath: path,
        network: network,
      );
      return Ok('[$fingerprint/$originPath]$xpub');
    } on Exception {
      return const Err(BullVaultInvalidSignerFailure());
    }
  }
}
