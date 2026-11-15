part of 'bitcoin_policy_codec.dart';

class _PolicyMapper {
  static ParsedBitcoinPolicy fromBdk({
    required bdk.Policy external,
    required bdk.Policy internal,
    bdk.Policy? externalKeyIdentities,
    bdk.Policy? internalKeyIdentities,
    required List<BitcoinDescriptorKey> descriptorKeys,
    Set<String> unspendablePolicyKeyIdentifiers = const {},
    bool isTaproot = false,
  }) => ParsedBitcoinPolicy(
    external: _spendingPolicy(
      external,
      externalKeyIdentities ?? external,
      _PolicyKeyResolver(descriptorKeys),
      unspendablePolicyKeyIdentifiers,
      isTaproot: isTaproot,
    ),
    internal: _spendingPolicy(
      internal,
      internalKeyIdentities ?? internal,
      _PolicyKeyResolver(descriptorKeys),
      unspendablePolicyKeyIdentifiers,
      isTaproot: isTaproot,
    ),
  );

  static ParsedKeychainPolicy _spendingPolicy(
    bdk.Policy policy,
    bdk.Policy keyIdentities,
    _PolicyKeyResolver keys,
    Set<String> unspendablePolicyKeyIdentifiers, {
    required bool isTaproot,
  }) {
    final identifiers = unspendablePolicyKeyIdentifiers
        .map((identifier) => identifier.toLowerCase())
        .toSet();
    var root = _withoutUnspendableInternalKey(
      _node(policy, keyIdentities, keys),
      identifiers,
    );
    final requiresTaprootChoice =
        isTaproot &&
        root.type == ParsedPolicyNodeType.threshold &&
        root.threshold == 1 &&
        root.children.length > 1;
    if (requiresTaprootChoice) {
      root = ParsedPolicyNode(
        id: root.id,
        type: root.type,
        threshold: root.threshold,
        requiresPath: true,
        children: root.children,
        pathChildIndices: root.pathChildIndices,
      );
    }
    return ParsedKeychainPolicy(
      root: root,
      requiresPath: policy.requiresPath() || requiresTaprootChoice,
    );
  }

  static ParsedPolicyNode _withoutUnspendableInternalKey(
    ParsedPolicyNode root,
    Set<String> identifiers,
  ) {
    if (identifiers.isEmpty ||
        root.type != ParsedPolicyNodeType.threshold ||
        root.threshold != 1) {
      return root;
    }
    final spendable = [
      for (final (index, child) in root.children.indexed)
        if (child.type != ParsedPolicyNodeType.signature ||
            !identifiers.contains(child.key?.value.toLowerCase()))
          (child: child, pathIndex: root.pathChildIndices[index]),
    ];
    if (spendable.length == root.children.length) return root;
    return ParsedPolicyNode(
      id: root.id,
      type: root.type,
      threshold: spendable.length == 1 ? 1 : root.threshold,
      requiresPath: true,
      children: spendable.map((entry) => entry.child).toList(),
      pathChildIndices: spendable.map((entry) => entry.pathIndex).toList(),
    );
  }

  static ParsedPolicyNode _node(
    bdk.Policy policy,
    bdk.Policy keyIdentities,
    _PolicyKeyResolver keys,
  ) {
    final id = policy.id();
    final item = policy.item();
    final keyIdentityItem = keyIdentities.item();

    return switch (item) {
      bdk.EcdsaSignatureSatisfiableItem() => ParsedPolicyNode(
        id: id,
        type: ParsedPolicyNodeType.signature,
        key: _key(_signatureKey(keyIdentityItem), keys),
      ),
      bdk.SchnorrSignatureSatisfiableItem() => ParsedPolicyNode(
        id: id,
        type: ParsedPolicyNodeType.signature,
        key: _key(_signatureKey(keyIdentityItem), keys),
      ),
      bdk.Sha256PreimageSatisfiableItem(:final hash) => ParsedPolicyNode(
        id: id,
        type: ParsedPolicyNodeType.sha256,
        hash: hash,
      ),
      bdk.Hash256PreimageSatisfiableItem(:final hash) => ParsedPolicyNode(
        id: id,
        type: ParsedPolicyNodeType.hash256,
        hash: hash,
      ),
      bdk.Ripemd160PreimageSatisfiableItem(:final hash) => ParsedPolicyNode(
        id: id,
        type: ParsedPolicyNodeType.ripemd160,
        hash: hash,
      ),
      bdk.Hash160PreimageSatisfiableItem(:final hash) => ParsedPolicyNode(
        id: id,
        type: ParsedPolicyNodeType.hash160,
        hash: hash,
      ),
      bdk.AbsoluteTimelockSatisfiableItem(:final value) => _absoluteTimelock(
        id: id,
        value: value,
      ),
      bdk.RelativeTimelockSatisfiableItem(:final value) => _relativeTimelock(
        id: id,
        sequence: value,
      ),
      bdk.MultisigSatisfiableItem(keys: final policyKeys, :final threshold) =>
        ParsedPolicyNode(
          id: id,
          type: ParsedPolicyNodeType.threshold,
          threshold: threshold,
          children: [
            for (final (index, _) in policyKeys.indexed)
              ParsedPolicyNode(
                id: '$id:$index',
                type: ParsedPolicyNodeType.signature,
                key: _key(
                  _multisigKeys(keyIdentityItem, policyKeys.length)[index],
                  keys,
                ),
              ),
          ],
        ),
      bdk.ThreshSatisfiableItem(:final items, :final threshold) =>
        ParsedPolicyNode(
          id: id,
          type: ParsedPolicyNodeType.threshold,
          threshold: threshold,
          requiresPath: policy.requiresPath(),
          children: [
            for (final (index, item) in items.indexed)
              _node(
                item,
                _thresholdItems(keyIdentityItem, items.length)[index],
                keys,
              ),
          ],
        ),
      _ => throw StateError('Unsupported BDK policy item'),
    };
  }

  static bdk.PkOrF _signatureKey(bdk.SatisfiableItem item) => switch (item) {
    bdk.EcdsaSignatureSatisfiableItem(:final key) => key,
    bdk.SchnorrSignatureSatisfiableItem(:final key) => key,
    _ => throw const UnsupportedBitcoinPolicyPathException(),
  };

  static List<bdk.PkOrF> _multisigKeys(
    bdk.SatisfiableItem item,
    int expectedLength,
  ) {
    if (item case bdk.MultisigSatisfiableItem(keys: final keys)
        when keys.length == expectedLength) {
      return keys;
    }
    throw const UnsupportedBitcoinPolicyPathException();
  }

  static List<bdk.Policy> _thresholdItems(
    bdk.SatisfiableItem item,
    int expectedLength,
  ) {
    if (item case bdk.ThreshSatisfiableItem(items: final items)
        when items.length == expectedLength) {
      return items;
    }
    throw const UnsupportedBitcoinPolicyPathException();
  }

  static ParsedPolicyKey _key(
    bdk.PkOrF key,
    _PolicyKeyResolver keys,
  ) => switch (key) {
    bdk.PubkeyPkOrF(:final value) =>
      keys.resolvePublicKey(value) ??
          ParsedPolicyKey(type: ParsedPolicyKeyType.publicKey, value: value),
    bdk.XOnlyPubkeyPkOrF(:final value) => ParsedPolicyKey(
      type: ParsedPolicyKeyType.xOnlyPublicKey,
      value: value,
    ),
    bdk.FingerprintPkOrF(:final value) =>
      keys.resolveFingerprint(value) ??
          ParsedPolicyKey(type: ParsedPolicyKeyType.fingerprint, value: value),
    _ => throw StateError('Unsupported BDK policy key'),
  };

  static ParsedPolicyNode _absoluteTimelock({
    required String id,
    required bdk.LockTime value,
  }) => switch (value) {
    bdk.BlocksLockTime(:final height) => ParsedPolicyNode(
      id: id,
      type: ParsedPolicyNodeType.absoluteBlockHeight,
      value: height,
    ),
    bdk.SecondsLockTime(:final consensusTime) => ParsedPolicyNode(
      id: id,
      type: ParsedPolicyNodeType.absoluteTimestamp,
      value: consensusTime,
    ),
    _ => throw StateError('Unsupported BDK absolute timelock'),
  };

  static ParsedPolicyNode _relativeTimelock({
    required String id,
    required int sequence,
  }) {
    const typeFlag = 1 << 22;
    const valueMask = 0xffff;
    final encodedValue = sequence & valueMask;
    final isTimeBased = sequence & typeFlag != 0;
    return ParsedPolicyNode(
      id: id,
      type: isTimeBased
          ? ParsedPolicyNodeType.relativeSeconds
          : ParsedPolicyNodeType.relativeBlocks,
      value: isTimeBased ? encodedValue * 512 : encodedValue,
    );
  }
}

final class _PolicyKeyResolver {
  final List<BitcoinDescriptorKey> descriptorKeys;
  final Map<String, int> _fingerprintOffsets = {};

  _PolicyKeyResolver(this.descriptorKeys);

  ParsedPolicyKey? resolveFingerprint(String fingerprint) {
    final normalized = fingerprint.toLowerCase();
    final matches = descriptorKeys
        .where(
          (key) =>
              key.masterFingerprint.toLowerCase() == normalized ||
              key.xpubFingerprint.toLowerCase() == normalized,
        )
        .toList();
    if (matches.isEmpty) return null;

    final offset = _fingerprintOffsets.update(
      normalized,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    if (offset >= matches.length) {
      if (matches.length == 1) {
        return ParsedPolicyKey(
          type: ParsedPolicyKeyType.descriptorKey,
          value: matches.single.id,
        );
      }
      throw const UnsupportedBitcoinPolicyPathException();
    }
    final match = matches[offset];
    return ParsedPolicyKey(
      type: ParsedPolicyKeyType.descriptorKey,
      value: match.id,
    );
  }

  ParsedPolicyKey? resolvePublicKey(String publicKey) {
    final normalized = publicKey.toLowerCase();
    final match = descriptorKeys
        .where((key) => key.xpub.toLowerCase() == normalized)
        .firstOrNull;
    if (match == null) return null;
    return ParsedPolicyKey(
      type: ParsedPolicyKeyType.descriptorKey,
      value: match.id,
    );
  }
}
