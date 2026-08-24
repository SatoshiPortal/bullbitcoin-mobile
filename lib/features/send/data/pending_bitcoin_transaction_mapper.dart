import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_path.dart';
import 'package:bb_mobile/features/send/data/models/pending_bitcoin_transaction_model.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';

class PendingBitcoinTransactionMapper {
  static PendingBitcoinTransaction toEntity(
    PendingBitcoinTransactionModel model,
  ) => PendingBitcoinTransaction(
    id: model.id,
    walletId: model.walletId,
    stage: PendingBitcoinTransactionStage.values.byName(model.stage),
    label: model.label,
    recipient: model.recipient,
    amount: model.amount,
    amountCurrencyCode: model.amountCurrencyCode,
    sendMax: model.sendMax,
    feeSelection: FeeSelection.values.byName(model.feeSelection),
    customFee: _customFee(model),
    replaceByFee: model.replaceByFee,
    payjoinOptedOut: model.payjoinOptedOut,
    selectedOutpoints: model.selectedOutpoints,
    policySelection: BitcoinPolicySelection(choices: model.policyChoices),
    psbt: model.psbt,
    finalTransaction: model.finalTransaction,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
    revision: model.revision,
  );

  static PendingBitcoinTransactionModel toModel(
    PendingBitcoinTransaction entity,
  ) {
    final customFee = entity.customFee;
    return PendingBitcoinTransactionModel(
      id: entity.id,
      walletId: entity.walletId,
      stage: entity.stage.name,
      label: entity.label,
      recipient: entity.recipient,
      amount: entity.amount,
      amountCurrencyCode: entity.amountCurrencyCode,
      sendMax: entity.sendMax,
      feeSelection: entity.feeSelection.name,
      customFeeKind: switch (customFee) {
        AbsoluteFee() => 'absolute',
        RelativeFee() => 'relative',
        null => null,
      },
      customFeeValue: switch (customFee) {
        AbsoluteFee(:final sats) => sats,
        RelativeFee(:final satPerKwu) => satPerKwu,
        null => null,
      },
      replaceByFee: entity.replaceByFee,
      payjoinOptedOut: entity.payjoinOptedOut,
      selectedOutpoints: entity.selectedOutpoints,
      policyChoices: entity.policySelection.choices,
      psbt: entity.psbt,
      finalTransaction: entity.finalTransaction,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      revision: entity.revision,
    );
  }

  static NetworkFee? _customFee(PendingBitcoinTransactionModel model) =>
      switch ((model.customFeeKind, model.customFeeValue)) {
        (null, null) => null,
        ('absolute', final value?) => NetworkFee.absolute(value),
        ('relative', final value?) => NetworkFee.relativeSatPerKwu(value),
        _ => throw const FormatException('Invalid custom fee'),
      };
}
