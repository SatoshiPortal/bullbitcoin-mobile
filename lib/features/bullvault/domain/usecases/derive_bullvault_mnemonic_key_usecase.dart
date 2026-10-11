import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/network_x.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:secrets/secrets.dart' show EphemeralMnemonic, Secrets, Language;

class DeriveBullVaultMnemonicKeyUsecase {
  final Secrets _secrets;

  const DeriveBullVaultMnemonicKeyUsecase(this._secrets);

  Future<Result<String, BullVaultFailure>> execute({
    required List<String> words,
    Language language = Language.english,
    required Network network,
  }) async {
    final path = Bip48Derivation.path(coinType: network.coinType, account: 0);
    return (await _secrets.preview.account(
          words: words,
          language: language,
          derivationPath: path,
          network: network.bitcoin,
        ))
        .map(
          (key) => '[${key.fingerprint.hex}/${path.substring(2)}]${key.xpub}',
        )
        .mapErr((_) => const BullVaultInvalidSignerFailure());
  }

  Future<Result<String, BullVaultFailure>> fromGenerated({
    required EphemeralMnemonic mnemonic,
    required Network network,
  }) async {
    final path = Bip48Derivation.path(coinType: network.coinType, account: 0);
    return (await mnemonic.account(
          derivationPath: path,
          network: network.bitcoin,
        ))
        .map(
          (key) => '[${key.fingerprint.hex}/${path.substring(2)}]${key.xpub}',
        )
        .mapErr((_) => const BullVaultInvalidSignerFailure());
  }
}
