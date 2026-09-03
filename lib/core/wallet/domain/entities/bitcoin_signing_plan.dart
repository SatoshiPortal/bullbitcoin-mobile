import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_node.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_path.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_wallet_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';

final class BitcoinSigningPlan {
  final BitcoinWalletPolicy policy;
  final BitcoinPolicySelection selection;
  final bool canFinalizeLocally;
  final Map<BitcoinPolicyKeychain, Set<String>>
  signedDescriptorKeyIdsByKeychain;
  final Map<String, Set<String>> signedDescriptorKeyIdsByOutpoint;
  final Map<String, BitcoinPolicyKeychain> inputKeychainsByOutpoint;
  final Set<BitcoinPolicyKeychain> inputKeychains;
  final Set<String> satisfiedPreimageKeys;
  final List<WalletSigner> eligibleSigners;

  BitcoinSigningPlan._({
    required this.policy,
    this.selection = const BitcoinPolicySelection.empty(),
    required this.canFinalizeLocally,
    this.signedDescriptorKeyIdsByKeychain = const {},
    this.signedDescriptorKeyIdsByOutpoint = const {},
    this.inputKeychainsByOutpoint = const {},
    this.inputKeychains = const {
      BitcoinPolicyKeychain.external,
      BitcoinPolicyKeychain.internal,
    },
    this.satisfiedPreimageKeys = const {},
    this.eligibleSigners = const [],
  });

  factory BitcoinSigningPlan.fromPolicy({
    required BitcoinWalletPolicy policy,
    required List<WalletSigner> signers,
    BitcoinPolicySelection selection = const BitcoinPolicySelection.empty(),
    Map<BitcoinPolicyKeychain, Set<String>> signedDescriptorKeyIdsByKeychain =
        const {},
    Map<String, Set<String>> signedDescriptorKeyIdsByOutpoint = const {},
    Map<String, BitcoinPolicyKeychain> inputKeychainsByOutpoint = const {},
    Set<BitcoinPolicyKeychain>? inputKeychains,
    Set<String> satisfiedPreimageKeys = const {},
  }) {
    final selectionComplete = policy.pathRequirements(selection).isEmpty;
    final usedKeychains = inputKeychains == null || inputKeychains.isEmpty
        ? const {BitcoinPolicyKeychain.external, BitcoinPolicyKeychain.internal}
        : Set<BitcoinPolicyKeychain>.unmodifiable(inputKeychains);
    final requiredKeys = policy.signatureKeys(
      selection,
      keychains: usedKeychains,
    );
    final eligibleSigners = [
      for (final signer in signers)
        if (signer.descriptorKeys.any(
          (descriptorKey) =>
              requiredKeys.any((key) => key.matches(descriptorKey)),
        ))
          signer,
    ];
    final signedByKeychain = <BitcoinPolicyKeychain, Set<String>>{
      for (final keychain in usedKeychains)
        keychain: Set.unmodifiable(
          signedDescriptorKeyIdsByKeychain[keychain] ?? const {},
        ),
    };
    final signedByOutpoint = {
      for (final entry in signedDescriptorKeyIdsByOutpoint.entries)
        entry.key: Set.unmodifiable(entry.value),
    };
    final inputEvidence = inputKeychainsByOutpoint.isEmpty
        ? [
            for (final keychain in usedKeychains)
              (
                keychain: keychain,
                signedDescriptorKeyIds: signedByKeychain[keychain] ?? const {},
              ),
          ]
        : [
            for (final entry in inputKeychainsByOutpoint.entries)
              (
                keychain: entry.value,
                signedDescriptorKeyIds: signedByOutpoint[entry.key] ?? const {},
              ),
          ];
    bool descriptorKeyIsSigned(
      WalletDescriptorKey descriptorKey,
      _InputSigningEvidence evidence,
    ) => evidence.signedDescriptorKeyIds.contains(descriptorKey.id);
    bool keyIsLocalOrSigned(
      BitcoinPolicyKey key,
      _InputSigningEvidence evidence,
    ) => eligibleSigners.any(
      (signer) => signer.descriptorKeys.any(
        (descriptorKey) =>
            key.matches(descriptorKey) &&
            (descriptorKeyIsSigned(descriptorKey, evidence) ||
                signer.signer == SignerEntity.local),
      ),
    );
    final canFinalizeLocally =
        selectionComplete &&
        inputEvidence.every(
          (evidence) => policy.canBeSatisfiedBy(
            selection: selection,
            keychains: {evidence.keychain},
            hasSignature: (key) => keyIsLocalOrSigned(key, evidence),
            hasPreimage: (hashlock) => satisfiedPreimageKeys.contains(
              '${hashlock.type.name}:${hashlock.hash.toLowerCase()}',
            ),
          ),
        );

    return BitcoinSigningPlan._(
      policy: policy,
      selection: selection,
      canFinalizeLocally: canFinalizeLocally,
      signedDescriptorKeyIdsByKeychain: Map.unmodifiable(signedByKeychain),
      signedDescriptorKeyIdsByOutpoint: Map.unmodifiable(signedByOutpoint),
      inputKeychainsByOutpoint: Map.unmodifiable(inputKeychainsByOutpoint),
      inputKeychains: usedKeychains,
      satisfiedPreimageKeys: Set.unmodifiable(satisfiedPreimageKeys),
      eligibleSigners: List.unmodifiable(eligibleSigners),
    );
  }

  bool get isSatisfied =>
      policy.pathRequirements(selection).isEmpty &&
      _inputEvidence.every(
        (evidence) => policy.canBeSatisfiedBy(
          selection: selection,
          keychains: {evidence.keychain},
          hasSignature: (key) => eligibleSigners.any(
            (signer) => signer.descriptorKeys.any(
              (descriptorKey) =>
                  key.matches(descriptorKey) &&
                  evidence.signedDescriptorKeyIds.contains(descriptorKey.id),
            ),
          ),
          hasPreimage: (hashlock) => satisfiedPreimageKeys.contains(
            '${hashlock.type.name}:${hashlock.hash.toLowerCase()}',
          ),
        ),
      );

  bool get hasSignatures =>
      signedDescriptorKeyIdsByKeychain.values.any((ids) => ids.isNotEmpty) ||
      signedDescriptorKeyIdsByOutpoint.values.any((ids) => ids.isNotEmpty);

  bool get requiresExternalSigning {
    if (isSatisfied) return false;
    final localSignerIds = {
      for (final signer in eligibleSigners)
        if (signer.signer == SignerEntity.local) signer.id,
    };
    return _signerRequirement.isSatisfiedBy({
          for (final signer in eligibleSigners) signer.id,
        }) &&
        !_signerRequirement.isSatisfiedBy(localSignerIds);
  }

  int get signersNeeded {
    if (isSatisfied) return 0;
    return _minimumSigners;
  }

  late final _signerRequirement =
      _SignerRequirement.threshold(_inputEvidence.length, [
        for (final evidence in _inputEvidence)
          _nodeSignerRequirement(
            node: switch (evidence.keychain) {
              BitcoinPolicyKeychain.external => policy.external.root,
              BitcoinPolicyKeychain.internal => policy.internal.root,
            },
            keychain: evidence.keychain,
            nodePath: 'root',
            selection: selection,
            signers: eligibleSigners,
            signedDescriptorKeyIds: evidence.signedDescriptorKeyIds,
          ),
      ]);
  late final int _minimumSigners = _signerRequirement.minimumSignerCount({
    for (final signer in eligibleSigners) signer.id,
  });

  bool requires(WalletSigner signer) =>
      eligibleSigners.any((eligible) => eligible.id == signer.id);

  bool requiresPassphrase(WalletSigner signer) {
    for (final evidence in _inputEvidence) {
      if (_relevantDescriptorKeys(
        policy: policy,
        selection: selection,
        signer: signer,
        keychain: evidence.keychain,
      ).any((key) => key.requiresPassphrase)) {
        return true;
      }
    }
    return false;
  }

  bool isSigned(WalletSigner signer) {
    var hasRelevantKey = false;
    for (final evidence in _inputEvidence) {
      final relevant = _relevantDescriptorKeys(
        policy: policy,
        selection: selection,
        signer: signer,
        keychain: evidence.keychain,
      );
      if (relevant.isEmpty) continue;
      hasRelevantKey = true;
      if (!relevant.every(
        (key) => evidence.signedDescriptorKeyIds.contains(key.id),
      )) {
        return false;
      }
    }
    return hasRelevantKey;
  }

  List<_InputSigningEvidence> get _inputEvidence =>
      inputKeychainsByOutpoint.isEmpty
      ? [
          for (final keychain in inputKeychains)
            (
              keychain: keychain,
              signedDescriptorKeyIds:
                  signedDescriptorKeyIdsByKeychain[keychain] ?? const {},
            ),
        ]
      : [
          for (final entry in inputKeychainsByOutpoint.entries)
            (
              keychain: entry.value,
              signedDescriptorKeyIds:
                  signedDescriptorKeyIdsByOutpoint[entry.key] ?? const {},
            ),
        ];
}

List<WalletDescriptorKey> _relevantDescriptorKeys({
  required BitcoinWalletPolicy policy,
  required BitcoinPolicySelection selection,
  required WalletSigner signer,
  required BitcoinPolicyKeychain keychain,
}) => [
  for (final descriptorKey in signer.descriptorKeys)
    if (policy
        .signatureKeys(selection, keychains: {keychain})
        .any((key) => key.matches(descriptorKey)))
      descriptorKey,
];

typedef _InputSigningEvidence = ({
  BitcoinPolicyKeychain keychain,
  Set<String> signedDescriptorKeyIds,
});

_SignerRequirement _nodeSignerRequirement({
  required BitcoinPolicyNode node,
  required BitcoinPolicyKeychain keychain,
  required String nodePath,
  required BitcoinPolicySelection selection,
  required List<WalletSigner> signers,
  required Set<String> signedDescriptorKeyIds,
}) {
  if (node is BitcoinSignaturePolicyNode) {
    final matching = [
      for (final signer in signers)
        for (final descriptorKey in signer.descriptorKeys)
          if (node.key.matches(descriptorKey)) (signer, descriptorKey),
    ];
    if (matching.any((match) => signedDescriptorKeyIds.contains(match.$2.id))) {
      return _SignerRequirement.threshold(0, const []);
    }
    return _SignerRequirement.signature({
      for (final match in matching) match.$1.id,
    });
  }
  if (node is! BitcoinThresholdPolicyNode) {
    return _SignerRequirement.threshold(0, const []);
  }

  final selected = node.requiresSelection
      ? selection.choiceFor(keychain: keychain, nodePath: nodePath)
      : null;
  final childIndices = selected ?? Iterable.generate(node.children.length);
  return _SignerRequirement.threshold(node.threshold, [
    for (final index in childIndices)
      _nodeSignerRequirement(
        node: node.children[index],
        keychain: keychain,
        nodePath: '$nodePath/$index',
        selection: selection,
        signers: signers,
        signedDescriptorKeyIds: signedDescriptorKeyIds,
      ),
  ]);
}

/// Signature requirements only: timelocks and preimages are checked by the policy.
final class _SignerRequirement {
  final Set<String> signerIds;
  final List<_SignerRequirement>? children;
  final int threshold;
  final bool disjointChildren;

  _SignerRequirement.signature(this.signerIds)
    : children = null,
      threshold = 1,
      disjointChildren = true;

  _SignerRequirement.threshold(
    this.threshold,
    List<_SignerRequirement> children,
  ) : children = children,
      signerIds = {for (final child in children) ...child.signerIds},
      disjointChildren = _areDisjoint(children);

  static bool _areDisjoint(List<_SignerRequirement> children) {
    final seen = <String>{};
    for (final child in children) {
      for (final id in child.signerIds) {
        if (!seen.add(id)) return false;
      }
    }
    return true;
  }

  bool isSatisfiedBy(Set<String> signers) =>
      lowerBound(signers, const {}, signers.length + 1) == 0;

  int lowerBound(Set<String> selected, Set<String> available, int impossible) {
    final children = this.children;
    if (children == null) {
      if (signerIds.any(selected.contains)) return 0;
      return signerIds.any(available.contains) ? 1 : impossible;
    }
    if (threshold == 0) return 0;
    if (children.length < threshold) return impossible;
    final costs = [
      for (final child in children)
        child.lowerBound(selected, available, impossible),
    ]..sort();
    if (costs[threshold - 1] >= impossible) return impossible;
    // Disjoint branches add costs; overlapping branches may share one signer.
    return disjointChildren
        ? costs.take(threshold).fold(0, (sum, cost) => sum + cost)
        : costs[threshold - 1];
  }

  int minimumSignerCount(Set<String> signers) {
    if (!isSatisfiedBy(signers)) return signers.length;
    final sufficient = {...signers};
    for (final id in signers) {
      sufficient.remove(id);
      if (!isSatisfiedBy(sufficient)) sufficient.add(id);
    }
    var best = sufficient.length;
    final remaining = {...signers};
    final selected = <String>{};
    final impossible = signers.length + 1;
    void search() {
      final minimum = lowerBound(selected, remaining, impossible);
      if (selected.length + minimum >= best) return;
      if (minimum == 0) {
        best = selected.length;
        return;
      }
      if (remaining.isEmpty) return;
      final id = remaining.first;
      remaining.remove(id);
      search();
      selected.add(id);
      search();
      selected.remove(id);
      remaining.add(id);
    }

    search();
    return best;
  }
}
