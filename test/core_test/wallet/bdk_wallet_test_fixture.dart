import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
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

({String external, String fingerprint, String internal, String xpub})
nestedSegwitSingleSignatureDescriptors(String words) {
  final root = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: bdk.Mnemonic.fromString(mnemonic: words),
    password: null,
  );
  final account = root.derive(path: bdk.DerivationPath(path: "m/49'/1'/0'"));
  return (
    external: bdk.Descriptor.newBip49(
      secretKey: root,
      keychainKind: bdk.KeychainKind.external_,
      networkKind: bdk.NetworkKind.test,
    ).toString(),
    fingerprint: account.asPublic().masterFingerprint(),
    internal: bdk.Descriptor.newBip49(
      secretKey: root,
      keychainKind: bdk.KeychainKind.internal,
      networkKind: bdk.NetworkKind.test,
    ).toString(),
    xpub: account.asPublic().toString(),
  );
}

({String external, String fingerprint, String internal, String xpub})
singleSignatureDescriptorsAtAccount(String words, {required int account}) {
  final root = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: bdk.Mnemonic.fromString(mnemonic: words),
    password: null,
  );
  final accountKey = root.derive(
    path: bdk.DerivationPath(path: "m/84'/1'/$account'"),
  );
  final publicKey = accountKey.asPublic();
  return (
    external: bdk.Descriptor(
      descriptor: 'wpkh($publicKey/0/*)',
      networkKind: bdk.NetworkKind.test,
    ).toString(),
    fingerprint: publicKey.masterFingerprint(),
    internal: bdk.Descriptor(
      descriptor: 'wpkh($publicKey/1/*)',
      networkKind: bdk.NetworkKind.test,
    ).toString(),
    xpub: publicKey.toString(),
  );
}

WalletSigner walletSigner({
  required String fingerprint,
  required String xpub,
  required SignerEntity signer,
}) => WalletSigner.single(
  id: 'signer-$fingerprint',
  descriptorKeyId: 'key-$fingerprint',
  masterFingerprint: fingerprint,
  xpubFingerprint: fingerprint,
  xpub: xpub,
  derivationPath: "m/48'/1'/0'/2'",
  signer: signer,
  signerDevice: null,
);

bool containsPolicyNode<T extends BitcoinPolicyNode>(BitcoinPolicyNode node) {
  if (node is T) return true;
  return node is BitcoinThresholdPolicyNode &&
      node.children.any(containsPolicyNode<T>);
}

T? findPolicyNode<T extends BitcoinPolicyNode>(BitcoinPolicyNode node) {
  if (node is T) return node;
  if (node is! BitcoinThresholdPolicyNode) return null;
  for (final child in node.children) {
    final match = findPolicyNode<T>(child);
    if (match != null) return match;
  }
  return null;
}

({String psbt, bool isFinalized}) signPsbt(
  BdkWalletDatasource datasource,
  String psbt, {
  required List<SignerDescriptorKeys> signers,
  required int signerIndex,
}) {
  final externalKeys = [
    for (var i = 0; i < signers.length; i++)
      i == signerIndex ? signers[i].externalPrivate : signers[i].externalPublic,
  ];
  final internalKeys = [
    for (var i = 0; i < signers.length; i++)
      i == signerIndex ? signers[i].internalPrivate : signers[i].internalPublic,
  ];

  return datasource.signPsbtWithDescriptor(
    psbt,
    descriptor: twoPathDescriptor(
      sortedMultisigDescriptor(externalKeys),
      sortedMultisigDescriptor(internalKeys),
    ),
    isTestnet: true,
  );
}

Set<String> signedFingerprints(String psbtBase64) {
  final psbt = bdk.Psbt(psbtBase64: psbtBase64);
  try {
    Set<String>? fingerprints;
    for (final input in psbt.input()) {
      final inputFingerprints = input.partialSigs.keys
          .map((publicKey) => input.bip32Derivation[publicKey]?.fingerprint)
          .whereType<String>()
          .map((fingerprint) => fingerprint.toLowerCase())
          .toSet();
      fingerprints = fingerprints == null
          ? inputFingerprints
          : fingerprints.intersection(inputFingerprints);
    }
    return Set.unmodifiable(fingerprints ?? const {});
  } finally {
    psbt.dispose();
  }
}

String sortedMultisigDescriptor(List<String> descriptorKeys) =>
    'wsh(sortedmulti(2,${descriptorKeys.join(',')}))';

String twoPathDescriptor(String externalDescriptor, String internalDescriptor) {
  final external = externalDescriptor.split('#').first;
  final internal = internalDescriptor.split('#').first;
  final expectedInternal = external.replaceAll('/0/*', '/1/*');
  if (expectedInternal == external || expectedInternal != internal) {
    throw ArgumentError('Descriptors do not form /0/* and /1/* paths');
  }
  return external.replaceAll('/0/*', '/<0;1>/*');
}

String buildUnsignedPsbt({
  required String descriptor,
  int amountSat = 50000,
  int inputCount = 1,
  int inputIndex = 0,
  bdk.Script? recipientScript,
  BitcoinPolicyPath? policyPath,
}) {
  final wallet = BdkFacade.createEphemeralDescriptorWallet(
    descriptor: descriptor,
    isTestnet: true,
  );
  for (var index = 0; index <= inputIndex; index++) {
    wallet.revealNextAddress(keychain: bdk.KeychainKind.external_);
  }
  final ownedAddress = wallet.peekAddress(
    keychain: bdk.KeychainKind.external_,
    index: inputIndex,
  );
  wallet.applyUnconfirmedTxs(
    unconfirmedTxs: [
      for (var index = 0; index < inputCount; index++)
        bdk.UnconfirmedTx(
          tx: fundingTransaction(
            ownedAddress.address.scriptPubkey(),
            previousTxByte: 0x22 + index,
          ),
          lastSeen: index + 1,
        ),
    ],
  );
  final recipient = wallet.peekAddress(
    keychain: bdk.KeychainKind.external_,
    index: 1,
  );

  var builder = bdk.TxBuilder()
      .addRecipient(
        script: recipientScript ?? recipient.address.scriptPubkey(),
        amount: bdk.Amount.fromSat(satoshi: amountSat),
      )
      .feeAbsolute(feeAmount: bdk.Amount.fromSat(satoshi: 1000));
  if (policyPath != null) {
    builder = builder
        .policyPath(
          policyPath: policyPath.external,
          keychain: bdk.KeychainKind.external_,
        )
        .policyPath(
          policyPath: policyPath.internal,
          keychain: bdk.KeychainKind.internal,
        );
  }
  return builder.finish(wallet: wallet).serialize();
}

bdk.Transaction fundingTransaction(
  bdk.Script scriptPubkey, {
  int previousTxByte = 0x22,
}) {
  final script = scriptPubkey.toBytes();
  return bdk.Transaction(
    transactionBytes: Uint8List.fromList([
      2,
      0,
      0,
      0,
      1,
      ...List<int>.filled(32, previousTxByte),
      0,
      0,
      0,
      0,
      0,
      0xff,
      0xff,
      0xff,
      0xff,
      1,
      0xa0,
      0x86,
      0x01,
      0,
      0,
      0,
      0,
      0,
      script.length,
      ...script,
      0,
      0,
      0,
      0,
    ]),
  );
}
