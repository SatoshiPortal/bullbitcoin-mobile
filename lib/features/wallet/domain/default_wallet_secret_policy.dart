import 'package:secrets/secrets.dart';

enum DefaultWalletSecretRefusal { nonMnemonic }

DefaultWalletSecretRefusal? defaultWalletSecretRefusal(SecretInfo info) {
  if (!info.isMnemonic) return DefaultWalletSecretRefusal.nonMnemonic;
  return null;
}
