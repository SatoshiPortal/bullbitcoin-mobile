import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stops at the minimum signer set for a threshold policy', () {
    final signers = [
      _signer('aaaaaaaa', SignerEntity.local),
      _signer('bbbbbbbb', SignerEntity.remote),
      _signer('cccccccc', SignerEntity.remote),
    ];
    final policy = _thresholdPolicy(
      threshold: 2,
      keyIds: signers.map((signer) => signer.descriptorKeys.single.id),
    );

    final unsigned = BitcoinSigningPlan.fromPolicy(
      policy: policy,
      signers: signers,
      inputKeychains: const {BitcoinPolicyKeychain.external},
    );
    final externalFirst = BitcoinSigningPlan.fromPolicy(
      policy: policy,
      signers: signers,
      signedDescriptorKeyIdsByKeychain: const {
        BitcoinPolicyKeychain.external: {'key-bbbbbbbb'},
      },
      inputKeychains: const {BitcoinPolicyKeychain.external},
    );
    final satisfied = BitcoinSigningPlan.fromPolicy(
      policy: policy,
      signers: signers,
      signedDescriptorKeyIdsByKeychain: const {
        BitcoinPolicyKeychain.external: {'key-bbbbbbbb', 'key-cccccccc'},
      },
      inputKeychains: const {BitcoinPolicyKeychain.external},
    );

    expect(unsigned.eligibleSigners, signers);
    expect(unsigned.signersNeeded, 2);
    expect(externalFirst.signersNeeded, 1);
    expect(satisfied.isSatisfied, isTrue);
    expect(satisfied.signersNeeded, 0);

    final groupedSigner = WalletSigner(
      id: 'signer-grouped',
      signer: SignerEntity.local,
      signerDevice: null,
      descriptorKeys: signers
          .take(2)
          .expand((signer) => signer.descriptorKeys)
          .map((key) => key.copyWith(signerId: 'signer-grouped'))
          .toList(),
    );
    final grouped = BitcoinSigningPlan.fromPolicy(
      policy: policy,
      signers: [groupedSigner, signers.last],
      inputKeychains: const {BitcoinPolicyKeychain.external},
    );

    expect(grouped.eligibleSigners, [groupedSigner, signers.last]);
    expect(grouped.signersNeeded, 1);
  });

  test('counts a Miniscript threshold path independently of path choice', () {
    final signers = [
      _signer('aaaaaaaa', SignerEntity.local),
      _signer('bbbbbbbb', SignerEntity.remote),
      _signer('cccccccc', SignerEntity.remote),
    ];
    final policy = _thresholdPolicy(
      threshold: 2,
      keyIds: signers.map((signer) => signer.descriptorKeys.single.id),
      requiresPath: true,
    );
    final selector = policy
        .pathSelectors(const BitcoinPolicySelection.empty())
        .single;
    final incomplete = BitcoinSigningPlan.fromPolicy(
      policy: policy,
      signers: signers,
      inputKeychains: const {BitcoinPolicyKeychain.external},
    );
    final selection = policy.select(
      current: const BitcoinPolicySelection.empty(),
      requirement: selector,
      selectedIndices: const {0, 1},
    );

    final plan = BitcoinSigningPlan.fromPolicy(
      policy: policy,
      selection: selection,
      signers: signers,
      signedDescriptorKeyIdsByKeychain: const {
        BitcoinPolicyKeychain.external: {'key-bbbbbbbb'},
      },
      inputKeychains: const {BitcoinPolicyKeychain.external},
    );

    expect(incomplete.eligibleSigners, signers);
    expect(incomplete.signersNeeded, 2);
    expect(incomplete.requiresExternalSigning, isTrue);
    expect(plan.eligibleSigners, signers.take(2));
    expect(plan.signersNeeded, 1);
    expect(plan.isSatisfied, isFalse);
  });

  test('evaluates threshold satisfaction for each input', () {
    final signers = [
      _signer('aaaaaaaa', SignerEntity.remote),
      _signer('bbbbbbbb', SignerEntity.remote),
      _signer('cccccccc', SignerEntity.remote),
    ];
    final policy = _thresholdPolicy(
      threshold: 2,
      keyIds: signers.map((signer) => signer.descriptorKeys.single.id),
    );

    final plan = BitcoinSigningPlan.fromPolicy(
      policy: policy,
      signers: signers,
      inputKeychains: const {BitcoinPolicyKeychain.external},
      inputKeychainsByOutpoint: const {
        'funding:0': BitcoinPolicyKeychain.external,
        'funding:1': BitcoinPolicyKeychain.external,
      },
      signedDescriptorKeyIdsByOutpoint: const {
        'funding:0': {'key-aaaaaaaa', 'key-bbbbbbbb'},
        'funding:1': {'key-bbbbbbbb', 'key-cccccccc'},
      },
    );

    expect(plan.isSatisfied, isTrue);
    expect(plan.signersNeeded, 0);
    expect(plan.isSigned(signers[1]), isTrue);
  });

  test('tracks signatures for the keychain used by every input', () {
    final local = _signer('aaaaaaaa', SignerEntity.local);
    final remote = _signer('bbbbbbbb', SignerEntity.remote);
    final policy = BitcoinWalletPolicy(
      external: BitcoinSpendingPolicy(
        requiresPath: false,
        root: BitcoinSignaturePolicyNode(
          id: 'external',
          key: BitcoinPolicyKey(
            kind: BitcoinPolicyKeyKind.descriptorKey,
            value: local.descriptorKeys.single.id,
          ),
        ),
      ),
      internal: BitcoinSpendingPolicy(
        requiresPath: false,
        root: BitcoinSignaturePolicyNode(
          id: 'internal',
          key: BitcoinPolicyKey(
            kind: BitcoinPolicyKeyKind.descriptorKey,
            value: remote.descriptorKeys.single.id,
          ),
        ),
      ),
    );

    final plan = BitcoinSigningPlan.fromPolicy(
      policy: policy,
      signers: [local, remote],
      inputKeychains: const {BitcoinPolicyKeychain.external},
      signedDescriptorKeyIdsByKeychain: const {
        BitcoinPolicyKeychain.external: {'key-aaaaaaaa'},
      },
      signedDescriptorKeyIdsByOutpoint: const {
        'funding:0': {'key-aaaaaaaa'},
        'funding:1': {'key-bbbbbbbb'},
      },
    );

    expect(plan.eligibleSigners, [local]);
    expect(plan.isSigned(local), isTrue);
    expect(plan.isSatisfied, isTrue);
    expect(plan.signedDescriptorKeyIdsByOutpoint, const {
      'funding:0': {'key-aaaaaaaa'},
      'funding:1': {'key-bbbbbbbb'},
    });
  });

  test('requires a supplied preimage for a hashlock path', () {
    final signer = _signer('aaaaaaaa', SignerEntity.local);
    final spendingPolicy = BitcoinSpendingPolicy(
      requiresPath: false,
      root: BitcoinThresholdPolicyNode(
        id: 'and',
        threshold: 2,
        children: [
          BitcoinSignaturePolicyNode(
            id: 'signature',
            key: BitcoinPolicyKey(
              kind: BitcoinPolicyKeyKind.descriptorKey,
              value: signer.descriptorKeys.single.id,
            ),
          ),
          BitcoinHashlockPolicyNode(
            id: 'hashlock',
            type: BitcoinHashlockType.sha256,
            hash: 'aa',
          ),
        ],
      ),
    );
    final policy = BitcoinWalletPolicy(
      external: spendingPolicy,
      internal: spendingPolicy,
    );
    BitcoinSigningPlan plan(Set<String> preimages) =>
        BitcoinSigningPlan.fromPolicy(
          policy: policy,
          signers: [signer],
          inputKeychains: const {BitcoinPolicyKeychain.external},
          signedDescriptorKeyIdsByKeychain: const {
            BitcoinPolicyKeychain.external: {'key-aaaaaaaa'},
          },
          satisfiedPreimageKeys: preimages,
        );

    final missingPreimage = plan(const {});
    expect(missingPreimage.isSatisfied, isFalse);
    expect(missingPreimage.requiresExternalSigning, isFalse);
    expect(missingPreimage.missingPreimages, hasLength(1));

    final satisfied = plan(const {'sha256:aa'});
    expect(satisfied.isSatisfied, isTrue);
    expect(satisfied.missingPreimages, isEmpty);
  });

  test('does not require a preimage when another branch is satisfied', () {
    final immediate = _signer('aaaaaaaa', SignerEntity.remote);
    final hashlocked = _signer('bbbbbbbb', SignerEntity.remote);
    final hashlock = BitcoinHashlockPolicyNode(
      id: 'hashlock',
      type: BitcoinHashlockType.sha256,
      hash: 'aa',
    );
    final spendingPolicy = BitcoinSpendingPolicy(
      requiresPath: false,
      root: BitcoinThresholdPolicyNode(
        id: 'or',
        threshold: 1,
        children: [
          BitcoinSignaturePolicyNode(
            id: 'immediate',
            key: BitcoinPolicyKey(
              kind: BitcoinPolicyKeyKind.descriptorKey,
              value: immediate.descriptorKeys.single.id,
            ),
          ),
          BitcoinThresholdPolicyNode(
            id: 'hashlocked-branch',
            threshold: 2,
            children: [
              BitcoinSignaturePolicyNode(
                id: 'hashlocked',
                key: BitcoinPolicyKey(
                  kind: BitcoinPolicyKeyKind.descriptorKey,
                  value: hashlocked.descriptorKeys.single.id,
                ),
              ),
              hashlock,
            ],
          ),
        ],
      ),
    );
    final policy = BitcoinWalletPolicy(
      external: spendingPolicy,
      internal: spendingPolicy,
    );
    final plan = BitcoinSigningPlan.fromPolicy(
      policy: policy,
      signers: [immediate, hashlocked],
      inputKeychains: const {BitcoinPolicyKeychain.external},
      signedDescriptorKeyIdsByKeychain: {
        BitcoinPolicyKeychain.external: {immediate.descriptorKeys.single.id},
      },
    );

    expect(plan.isSatisfied, isTrue);
    expect(plan.missingPreimages, isEmpty);
  });
}

WalletSigner _signer(String fingerprint, SignerEntity signer) =>
    WalletSigner.single(
      id: 'signer-$fingerprint',
      descriptorKeyId: 'key-$fingerprint',
      masterFingerprint: fingerprint,
      xpubFingerprint: fingerprint,
      xpub: 'tpub-$fingerprint',
      signer: signer,
      signerDevice: null,
    );

BitcoinWalletPolicy _thresholdPolicy({
  required int threshold,
  required Iterable<String> keyIds,
  bool requiresPath = false,
}) {
  BitcoinSpendingPolicy spendingPolicy() => BitcoinSpendingPolicy(
    requiresPath: requiresPath,
    root: BitcoinThresholdPolicyNode(
      id: 'threshold',
      threshold: threshold,
      requiresPath: requiresPath,
      children: [
        for (final keyId in keyIds)
          BitcoinSignaturePolicyNode(
            id: keyId,
            key: BitcoinPolicyKey(
              kind: BitcoinPolicyKeyKind.descriptorKey,
              value: keyId,
            ),
          ),
      ],
    ),
  );
  return BitcoinWalletPolicy(
    external: spendingPolicy(),
    internal: spendingPolicy(),
  );
}
