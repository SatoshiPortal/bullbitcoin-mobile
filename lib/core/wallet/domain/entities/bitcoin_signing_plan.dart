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

  const BitcoinSigningPlan._({
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

  bool get requiresExternalSigning {
    if (isSatisfied) return false;
    final localSignerIds = {
      for (final signer in eligibleSigners)
        if (signer.signer == SignerEntity.local) signer.id,
    };
    final solutions = _policySignerSets(
      policy: policy,
      selection: selection,
      signers: eligibleSigners,
      inputEvidence: _inputEvidence,
    );
    return solutions.isNotEmpty && !solutions.any(localSignerIds.containsAll);
  }

  List<BitcoinHashlockPolicyNode> get missingPreimages {
    if (isSatisfied) return const [];
    return List.unmodifiable(
      policy
          .requiredHashlocks(selection)
          .where(
            (hashlock) => !satisfiedPreimageKeys.contains(
              '${hashlock.type.name}:${hashlock.hash.toLowerCase()}',
            ),
          ),
    );
  }

  int get signersNeeded {
    if (isSatisfied) return 0;
    final solutions = _policySignerSets(
      policy: policy,
      selection: selection,
      signers: eligibleSigners,
      inputEvidence: _inputEvidence,
    );
    if (solutions.isEmpty) return eligibleSigners.length;
    return solutions
        .map((solution) => solution.length)
        .reduce((smallest, count) => count < smallest ? count : smallest);
  }

  bool requires(WalletSigner signer) =>
      eligibleSigners.any((eligible) => eligible.id == signer.id);

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

List<Set<String>> _policySignerSets({
  required BitcoinWalletPolicy policy,
  required BitcoinPolicySelection selection,
  required List<WalletSigner> signers,
  required List<_InputSigningEvidence> inputEvidence,
}) {
  var solutions = <Set<String>>[<String>{}];
  for (final evidence in inputEvidence) {
    solutions = _mergeSignerSets(
      solutions,
      _nodeSignerSets(
        node: switch (evidence.keychain) {
          BitcoinPolicyKeychain.external => policy.external.root,
          BitcoinPolicyKeychain.internal => policy.internal.root,
        },
        keychain: evidence.keychain,
        nodePath: 'root',
        selection: selection,
        signers: signers,
        signedDescriptorKeyIds: evidence.signedDescriptorKeyIds,
      ),
    );
  }
  return solutions;
}

List<Set<String>> _nodeSignerSets({
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
      return [<String>{}];
    }
    return _minimalSignerSets([
      for (final match in matching) {match.$1.id},
    ]);
  }
  if (node is! BitcoinThresholdPolicyNode) return [<String>{}];

  final selected = node.requiresSelection
      ? selection.choiceFor(keychain: keychain, nodePath: nodePath)
      : null;
  final childIndices = selected ?? Iterable.generate(node.children.length);
  final combinations = List.generate(node.threshold + 1, (_) => <Set<String>>[])
    ..[0].add(<String>{});
  for (final index in childIndices) {
    final childSets = _nodeSignerSets(
      node: node.children[index],
      keychain: keychain,
      nodePath: '$nodePath/$index',
      selection: selection,
      signers: signers,
      signedDescriptorKeyIds: signedDescriptorKeyIds,
    );
    for (var count = node.threshold - 1; count >= 0; count--) {
      if (combinations[count].isEmpty || childSets.isEmpty) continue;
      combinations[count + 1] = _minimalSignerSets([
        ...combinations[count + 1],
        for (final existing in combinations[count])
          for (final child in childSets) {...existing, ...child},
      ]);
    }
  }
  return combinations[node.threshold];
}

List<Set<String>> _mergeSignerSets(
  List<Set<String>> first,
  List<Set<String>> second,
) {
  if (first.isEmpty || second.isEmpty) return const [];
  return _minimalSignerSets([
    for (final left in first)
      for (final right in second) {...left, ...right},
  ]);
}

List<Set<String>> _minimalSignerSets(Iterable<Set<String>> candidates) {
  final ordered = candidates.toList()
    ..sort((first, second) => first.length.compareTo(second.length));
  final minimal = <Set<String>>[];
  for (final candidate in ordered) {
    if (minimal.any(candidate.containsAll)) continue;
    minimal.add(Set.unmodifiable(candidate));
  }
  return List.unmodifiable(minimal);
}
