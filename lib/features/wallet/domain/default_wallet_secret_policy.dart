import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:secrets/secrets.dart';

enum DefaultWalletSecretRefusal { passphrase, nonMnemonic, nonEnglish }

// TODO: relax English-only after the pinned LWK supports seed-based Liquid APIs.
DefaultWalletSecretRefusal? defaultWalletSecretRefusal(SecretInfo info) {
  if (info.hasPassphrase) return DefaultWalletSecretRefusal.passphrase;
  if (!info.isMnemonic) return DefaultWalletSecretRefusal.nonMnemonic;
  if (info.language != bip39.Language.english) {
    return DefaultWalletSecretRefusal.nonEnglish;
  }
  return null;
}
