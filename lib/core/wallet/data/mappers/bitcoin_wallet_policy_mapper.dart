import 'package:bb_mobile/core/wallet/data/models/bitcoin_wallet_policy_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/domain/unsupported_bitcoin_policy_path_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

class BitcoinWalletPolicyMapper {
  static BitcoinWalletPolicyModel fromBdk({
    required bdk.Policy external,
    required bdk.Policy internal,
    bdk.Policy? externalKeyIdentities,
    bdk.Policy? internalKeyIdentities,
    required List<WalletDescriptorKeyModel> descriptorKeys,
    Set<String> unspendablePolicyKeyIdentifiers = const {},
    bool isTaproot = false,
  }) => BitcoinWalletPolicyModel(
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

  static BitcoinWalletPolicy toEntity(BitcoinWalletPolicyModel model) =>
      BitcoinWalletPolicy(
        external: _spendingPolicyEntity(model.external),
        internal: _spendingPolicyEntity(model.internal),
      );

  static BitcoinSpendingPolicyModel _spendingPolicy(
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
        root.type == BitcoinPolicyNodeModelType.threshold &&
        root.threshold == 1 &&
        root.children.length > 1;
    if (requiresTaprootChoice) {
      root = BitcoinPolicyNodeModel(
        id: root.id,
        type: root.type,
        threshold: root.threshold,
        requiresPath: true,
        children: root.children,
        pathChildIndices: root.pathChildIndices,
      );
    }
    return BitcoinSpendingPolicyModel(
      root: root,
      requiresPath: policy.requiresPath() || requiresTaprootChoice,
    );
  }

  static BitcoinPolicyNodeModel _withoutUnspendableInternalKey(
    BitcoinPolicyNodeModel root,
    Set<String> identifiers,
  ) {
    if (identifiers.isEmpty ||
        root.type != BitcoinPolicyNodeModelType.threshold ||
        root.threshold != 1) {
      return root;
    }
    final spendable = [
      for (final (index, child) in root.children.indexed)
        if (child.type != BitcoinPolicyNodeModelType.signature ||
            !identifiers.contains(child.key?.value.toLowerCase()))
          (child: child, pathIndex: root.pathChildIndices[index]),
    ];
    if (spendable.length == root.children.length) return root;
    return BitcoinPolicyNodeModel(
      id: root.id,
      type: root.type,
      threshold: spendable.length == 1 ? 1 : root.threshold,
      requiresPath: true,
      children: spendable.map((entry) => entry.child).toList(),
      pathChildIndices: spendable.map((entry) => entry.pathIndex).toList(),
    );
  }

  static BitcoinPolicyNodeModel _node(
    bdk.Policy policy,
    bdk.Policy keyIdentities,
    _PolicyKeyResolver keys,
  ) {
    final id = policy.id();
    final item = policy.item();
    final keyIdentityItem = keyIdentities.item();

    return switch (item) {
      bdk.EcdsaSignatureSatisfiableItem() => BitcoinPolicyNodeModel(
        id: id,
        type: BitcoinPolicyNodeModelType.signature,
        key: _key(_signatureKey(keyIdentityItem), keys),
      ),
      bdk.SchnorrSignatureSatisfiableItem() => BitcoinPolicyNodeModel(
        id: id,
        type: BitcoinPolicyNodeModelType.signature,
        key: _key(_signatureKey(keyIdentityItem), keys),
      ),
      bdk.Sha256PreimageSatisfiableItem(:final hash) => BitcoinPolicyNodeModel(
        id: id,
        type: BitcoinPolicyNodeModelType.sha256,
        hash: hash,
      ),
      bdk.Hash256PreimageSatisfiableItem(:final hash) => BitcoinPolicyNodeModel(
        id: id,
        type: BitcoinPolicyNodeModelType.hash256,
        hash: hash,
      ),
      bdk.Ripemd160PreimageSatisfiableItem(:final hash) =>
        BitcoinPolicyNodeModel(
          id: id,
          type: BitcoinPolicyNodeModelType.ripemd160,
          hash: hash,
        ),
      bdk.Hash160PreimageSatisfiableItem(:final hash) => BitcoinPolicyNodeModel(
        id: id,
        type: BitcoinPolicyNodeModelType.hash160,
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
        BitcoinPolicyNodeModel(
          id: id,
          type: BitcoinPolicyNodeModelType.threshold,
          threshold: threshold,
          children: [
            for (final (index, _) in policyKeys.indexed)
              BitcoinPolicyNodeModel(
                id: '$id:$index',
                type: BitcoinPolicyNodeModelType.signature,
                key: _key(
                  _multisigKeys(keyIdentityItem, policyKeys.length)[index],
                  keys,
                ),
              ),
          ],
        ),
      bdk.ThreshSatisfiableItem(:final items, :final threshold) =>
        BitcoinPolicyNodeModel(
          id: id,
          type: BitcoinPolicyNodeModelType.threshold,
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
    if (item case bdk.MultisigSatisfiableItem(
      keys: final keys,
    ) when keys.length == expectedLength) {
      return keys;
    }
    throw const UnsupportedBitcoinPolicyPathException();
  }

  static List<bdk.Policy> _thresholdItems(
    bdk.SatisfiableItem item,
    int expectedLength,
  ) {
    if (item case bdk.ThreshSatisfiableItem(
      items: final items,
    ) when items.length == expectedLength) {
      return items;
    }
    throw const UnsupportedBitcoinPolicyPathException();
  }

  static BitcoinPolicyKeyModel _key(bdk.PkOrF key, _PolicyKeyResolver keys) =>
      switch (key) {
        bdk.PubkeyPkOrF(:final value) =>
          keys.resolvePublicKey(value) ??
              BitcoinPolicyKeyModel(
                type: BitcoinPolicyKeyModelType.publicKey,
                value: value,
              ),
        bdk.XOnlyPubkeyPkOrF(:final value) => BitcoinPolicyKeyModel(
          type: BitcoinPolicyKeyModelType.xOnlyPublicKey,
          value: value,
        ),
        bdk.FingerprintPkOrF(:final value) =>
          keys.resolveFingerprint(value) ??
              BitcoinPolicyKeyModel(
                type: BitcoinPolicyKeyModelType.fingerprint,
                value: value,
              ),
        _ => throw StateError('Unsupported BDK policy key'),
      };

  static BitcoinPolicyNodeModel _absoluteTimelock({
    required String id,
    required bdk.LockTime value,
  }) => switch (value) {
    bdk.BlocksLockTime(:final height) => BitcoinPolicyNodeModel(
      id: id,
      type: BitcoinPolicyNodeModelType.absoluteBlockHeight,
      value: height,
    ),
    bdk.SecondsLockTime(:final consensusTime) => BitcoinPolicyNodeModel(
      id: id,
      type: BitcoinPolicyNodeModelType.absoluteTimestamp,
      value: consensusTime,
    ),
    _ => throw StateError('Unsupported BDK absolute timelock'),
  };

  static BitcoinPolicyNodeModel _relativeTimelock({
    required String id,
    required int sequence,
  }) {
    const typeFlag = 1 << 22;
    const valueMask = 0xffff;
    final encodedValue = sequence & valueMask;
    final isTimeBased = sequence & typeFlag != 0;
    return BitcoinPolicyNodeModel(
      id: id,
      type: isTimeBased
          ? BitcoinPolicyNodeModelType.relativeSeconds
          : BitcoinPolicyNodeModelType.relativeBlocks,
      value: isTimeBased ? encodedValue * 512 : encodedValue,
    );
  }

  static BitcoinSpendingPolicy _spendingPolicyEntity(
    BitcoinSpendingPolicyModel model,
  ) => BitcoinSpendingPolicy(
    root: _nodeEntity(model.root),
    requiresPath: model.requiresPath,
  );

  static BitcoinPolicyNode _nodeEntity(BitcoinPolicyNodeModel model) =>
      switch (model.type) {
        BitcoinPolicyNodeModelType.signature => BitcoinSignaturePolicyNode(
          id: model.id,
          key: _keyEntity(model.key!),
        ),
        BitcoinPolicyNodeModelType.sha256 => BitcoinHashlockPolicyNode(
          id: model.id,
          type: BitcoinHashlockType.sha256,
          hash: model.hash!,
        ),
        BitcoinPolicyNodeModelType.hash256 => BitcoinHashlockPolicyNode(
          id: model.id,
          type: BitcoinHashlockType.hash256,
          hash: model.hash!,
        ),
        BitcoinPolicyNodeModelType.ripemd160 => BitcoinHashlockPolicyNode(
          id: model.id,
          type: BitcoinHashlockType.ripemd160,
          hash: model.hash!,
        ),
        BitcoinPolicyNodeModelType.hash160 => BitcoinHashlockPolicyNode(
          id: model.id,
          type: BitcoinHashlockType.hash160,
          hash: model.hash!,
        ),
        BitcoinPolicyNodeModelType.absoluteBlockHeight =>
          BitcoinAbsoluteTimelockPolicyNode(
            id: model.id,
            type: BitcoinAbsoluteTimelockType.blockHeight,
            value: model.value!,
          ),
        BitcoinPolicyNodeModelType.absoluteTimestamp =>
          BitcoinAbsoluteTimelockPolicyNode(
            id: model.id,
            type: BitcoinAbsoluteTimelockType.timestamp,
            value: model.value!,
          ),
        BitcoinPolicyNodeModelType.relativeBlocks =>
          BitcoinRelativeTimelockPolicyNode(
            id: model.id,
            type: BitcoinRelativeTimelockType.blocks,
            value: model.value!,
          ),
        BitcoinPolicyNodeModelType.relativeSeconds =>
          BitcoinRelativeTimelockPolicyNode(
            id: model.id,
            type: BitcoinRelativeTimelockType.seconds,
            value: model.value!,
          ),
        BitcoinPolicyNodeModelType.threshold => BitcoinThresholdPolicyNode(
          id: model.id,
          threshold: model.threshold!,
          requiresPath: model.requiresPath,
          children: model.children.map(_nodeEntity).toList(),
          pathChildIndices: model.pathChildIndices,
        ),
      };

  static BitcoinPolicyKey _keyEntity(BitcoinPolicyKeyModel model) =>
      BitcoinPolicyKey(
        kind: switch (model.type) {
          BitcoinPolicyKeyModelType.descriptorKey =>
            BitcoinPolicyKeyKind.descriptorKey,
          BitcoinPolicyKeyModelType.publicKey => BitcoinPolicyKeyKind.publicKey,
          BitcoinPolicyKeyModelType.xOnlyPublicKey =>
            BitcoinPolicyKeyKind.xOnlyPublicKey,
          BitcoinPolicyKeyModelType.fingerprint =>
            BitcoinPolicyKeyKind.fingerprint,
        },
        value: model.value,
      );
}

final class _PolicyKeyResolver {
  final List<WalletDescriptorKeyModel> descriptorKeys;
  final Map<String, int> _fingerprintOffsets = {};

  _PolicyKeyResolver(this.descriptorKeys);

  BitcoinPolicyKeyModel? resolveFingerprint(String fingerprint) {
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
        return BitcoinPolicyKeyModel(
          type: BitcoinPolicyKeyModelType.descriptorKey,
          value: matches.single.id,
        );
      }
      throw const UnsupportedBitcoinPolicyPathException();
    }
    final match = matches[offset];
    return BitcoinPolicyKeyModel(
      type: BitcoinPolicyKeyModelType.descriptorKey,
      value: match.id,
    );
  }

  BitcoinPolicyKeyModel? resolvePublicKey(String publicKey) {
    final normalized = publicKey.toLowerCase();
    final match = descriptorKeys
        .where((key) => key.xpub.toLowerCase() == normalized)
        .firstOrNull;
    if (match == null) return null;
    return BitcoinPolicyKeyModel(
      type: BitcoinPolicyKeyModelType.descriptorKey,
      value: match.id,
    );
  }
}
