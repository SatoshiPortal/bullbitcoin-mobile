enum Bip85Status { active, inactive, revoked }

enum Bip85Application { bip39, wif, xprv, hex, pwdBase64, pwdBase85, rsa, dice }

class Bip85DerivationEntity {
  final String path;
  final String xprvFingerprint;
  final String? alias;
  final Bip85Status status;
  final Bip85Application application;
  final int index;

  Bip85DerivationEntity({
    required this.path,
    required this.xprvFingerprint,
    required this.alias,
    required this.status,
    required this.application,
    required this.index,
  });
}
