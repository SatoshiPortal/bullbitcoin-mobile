import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_review.dart';

const localFingerprint = 'aabbccdd';
const remoteFingerprint = '11223344';
const testPsbtBase64 =
    'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9'
    '////AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAU'
    'MzMzMzMzMzMzMzMzMzMzMzMzMzMAAA==';

Wallet psbtSigningWallet({
  bool hasLocalSigner = true,
  bool includeRemoteSigner = true,
  bool remoteSignerIsLocal = false,
  bool localRequiresPassphrase = false,
}) => Wallet(
  origin: 'wallet',
  network: Network.bitcoinTestnet,
  signers: [
    WalletSigner(
      id: 'signer-local',
      signer: hasLocalSigner ? SignerEntity.local : SignerEntity.remote,
      signerDevice: null,
      localSeedFingerprint: hasLocalSigner ? localFingerprint : null,
      descriptorKeys: [
        WalletDescriptorKey(
          id: 'key-local',
          signerId: 'signer-local',
          masterFingerprint: localFingerprint,
          xpubFingerprint: localFingerprint,
          xpub: 'tpub-local',
          derivationPath: "m/48'/1'/0'/2'",
          requiresPassphrase: localRequiresPassphrase,
        ),
      ],
    ),
    if (includeRemoteSigner)
      WalletSigner.single(
        id: 'signer-remote',
        descriptorKeyId: 'key-remote',
        masterFingerprint: remoteFingerprint,
        xpubFingerprint: remoteFingerprint,
        xpub: 'tpub-remote',
        derivationPath: "m/48'/1'/0'/2'",
        signer: remoteSignerIsLocal ? SignerEntity.local : SignerEntity.remote,
        signerDevice: null,
      ),
  ],
  scriptType: null,
  publicDescriptor: 'wsh(or_d(...))',
  balanceSat: BigInt.zero,
);

BitcoinPsbtReview psbtReview({
  Set<String> signedDescriptorKeyIds = const {},
  Map<String, Set<String>>? signedDescriptorKeyIdsByOutpoint,
  Map<String, Set<String>>? localDescriptorKeyIdsByOutpoint,
  int sequence = 0xfffffffd,
  int lockTime = 0,
}) => BitcoinPsbtReview(
  transactionId: 'txid',
  inputs: [
    for (final entry
        in (signedDescriptorKeyIdsByOutpoint ??
                {'00:0': signedDescriptorKeyIds})
            .entries)
      BitcoinPsbtInputReview(
        outpoint: entry.key,
        amountSat: BigInt.zero,
        keychain: BitcoinPolicyKeychain.external,
        localDescriptorKeyIds:
            localDescriptorKeyIdsByOutpoint?[entry.key] ?? const {'key-local'},
        sequence: sequence,
        signedDescriptorKeyIds: entry.value,
      ),
  ],
  outputs: [
    BitcoinPsbtOutputReview(
      index: 0,
      amountSat: BigInt.from(9000),
      address: 'tb1qrecipient',
      scriptHex: '0014aa',
      isWalletOwned: false,
    ),
  ],
  feeSat: BigInt.from(1000),
  estimatedTransactionVsize: 100,
  lockTime: lockTime,
  version: 2,
);

BitcoinPolicyMaturity psbtPolicyMaturity({int confirmations = 25}) =>
    BitcoinPolicyMaturity(
      tipHeight: 100,
      medianTimePast: null,
      utxos: [
        BitcoinPolicyUtxoMaturity(
          outpoint: '00:0',
          keychain: BitcoinPolicyKeychain.external,
          amountSat: BigInt.from(10000),
          confirmations: confirmations,
        ),
      ],
    );

BitcoinWalletPolicy singleLocalPolicy() {
  final key = BitcoinPolicyKey(
    kind: BitcoinPolicyKeyKind.fingerprint,
    value: localFingerprint,
  );
  final spendingPolicy = BitcoinSpendingPolicy(
    root: BitcoinSignaturePolicyNode(id: 'local', key: key),
    requiresPath: false,
  );
  return BitcoinWalletPolicy(
    external: spendingPolicy,
    internal: spendingPolicy,
  );
}

BitcoinWalletPolicy absoluteChoicePolicy() {
  BitcoinSpendingPolicy spendingPolicy() => BitcoinSpendingPolicy(
    requiresPath: true,
    root: BitcoinThresholdPolicyNode(
      id: 'root',
      threshold: 1,
      requiresPath: true,
      children: [
        BitcoinSignaturePolicyNode(
          id: 'local',
          key: BitcoinPolicyKey(
            kind: BitcoinPolicyKeyKind.fingerprint,
            value: localFingerprint,
          ),
        ),
        BitcoinThresholdPolicyNode(
          id: 'delayed',
          threshold: 2,
          children: [
            BitcoinAbsoluteTimelockPolicyNode(
              id: 'delay',
              type: BitcoinAbsoluteTimelockType.blockHeight,
              value: 200,
            ),
            BitcoinSignaturePolicyNode(
              id: 'remote',
              key: BitcoinPolicyKey(
                kind: BitcoinPolicyKeyKind.fingerprint,
                value: remoteFingerprint,
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return BitcoinWalletPolicy(
    external: spendingPolicy(),
    internal: spendingPolicy(),
  );
}

PsbtSigningReview psbtSigningReview({
  required BitcoinWalletPolicy policy,
  Wallet? wallet,
  BitcoinPsbtReview? transaction,
  String psbt = 'unsigned',
  bool transactionTimingVerified = true,
}) {
  final signingWallet = wallet ?? psbtSigningWallet();
  final transactionReview = transaction ?? psbtReview();
  return PsbtSigningReview(
    wallet: signingWallet,
    psbt: psbt,
    transaction: transactionReview,
    policy: policy,
    transactionTimingVerified: transactionTimingVerified,
  );
}
