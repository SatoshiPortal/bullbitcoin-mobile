import 'package:secrets/secrets.dart';

enum DefaultWalletSecretRefusal { passphrase, nonMnemonic }

DefaultWalletSecretRefusal? defaultWalletSecretRefusal(SecretInfo info) {
  if (info.hasPassphrase) return DefaultWalletSecretRefusal.passphrase;
  if (!info.isMnemonic) return DefaultWalletSecretRefusal.nonMnemonic;
  return null;
}
