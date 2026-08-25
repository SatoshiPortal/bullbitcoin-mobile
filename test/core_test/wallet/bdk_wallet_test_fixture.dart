import 'package:bull_sdk/bdk.dart' as bdk;

typedef SignerDescriptorKeys = ({
  String externalPrivate,
  String externalPublic,
  String fingerprint,
  String internalPrivate,
  String internalPublic,
  String xpub,
});

const testMnemonics = [
  'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
  'legal winner thank year wave sausage worth useful legal winner thank yellow',
  'letter advice cage absurd amount doctor acoustic avoid letter advice cage above',
];

SignerDescriptorKeys deriveSignerKeys(String words) =>
    deriveSignerKeysAtAccount(words, account: 0);

SignerDescriptorKeys deriveSignerKeysAtAccount(
  String words, {
  required int account,
}) {
  final root = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: bdk.Mnemonic.fromString(mnemonic: words),
    password: null,
  );
  final accountKey = root.derive(
    path: bdk.DerivationPath(path: "m/48'/1'/$account'/2'"),
  );
  return (
    externalPrivate: '$accountKey/0/*',
    externalPublic: '${accountKey.asPublic()}/0/*',
    fingerprint: accountKey.asPublic().masterFingerprint(),
    internalPrivate: '$accountKey/1/*',
    internalPublic: '${accountKey.asPublic()}/1/*',
    xpub: accountKey.asPublic().toString(),
  );
}

({String external, String fingerprint, String internal, String xpub})
singleSignatureDescriptors(String words) {
  final root = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: bdk.Mnemonic.fromString(mnemonic: words),
    password: null,
  );
  final account = root.derive(path: bdk.DerivationPath(path: "m/84'/1'/0'"));
  return (
    external: bdk.Descriptor.newBip84(
      secretKey: root,
      keychainKind: bdk.KeychainKind.external_,
      networkKind: bdk.NetworkKind.test,
    ).toString(),
    fingerprint: account.asPublic().masterFingerprint(),
    internal: bdk.Descriptor.newBip84(
      secretKey: root,
      keychainKind: bdk.KeychainKind.internal,
      networkKind: bdk.NetworkKind.test,
    ).toString(),
    xpub: account.asPublic().toString(),
  );
}
