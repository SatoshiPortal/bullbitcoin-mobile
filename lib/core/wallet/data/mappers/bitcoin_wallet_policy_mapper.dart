import 'package:bb_mobile/core/wallet/data/models/bitcoin_wallet_policy_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';

class BitcoinWalletPolicyMapper {
  static BitcoinWalletPolicy toEntity(BitcoinWalletPolicyModel model) =>
      BitcoinWalletPolicy(
        external: _spendingPolicyEntity(model.external),
        internal: _spendingPolicyEntity(model.internal),
      );

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
