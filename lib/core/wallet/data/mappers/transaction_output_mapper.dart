import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';

class TransactionOutputMapper {
  static TransactionOutputModel fromEntity(
    TransactionOutput transactionOutput,
  ) {
    switch (transactionOutput) {
      case BitcoinTransactionOutput _:
        return TransactionOutputModel.bitcoin(
          txId: transactionOutput.txId,
          vout: transactionOutput.vout,
          value: transactionOutput.value,
          scriptPubkey: transactionOutput.scriptPubkey,
          address: transactionOutput.address,
        );
      case LiquidTransactionOutput _:
        return TransactionOutputModel.liquid(
          txId: transactionOutput.txId,
          vout: transactionOutput.vout,
          value: transactionOutput.value,
          scriptPubkey: transactionOutput.scriptPubkey,
          standardAddress: transactionOutput.standardAddress,
          confidentialAddress: transactionOutput.confidentialAddress,
        );
    }
  }

  static TransactionOutput toEntity(
    TransactionOutputModel transactionOutputModel, {
    List<String> labels = const [],
    List<String> addressLabels = const [],
    bool isFrozen = false,
  }) {
    switch (transactionOutputModel) {
      case BitcoinTransactionOutputModel _:
        return TransactionOutput.bitcoin(
          txId: transactionOutputModel.txId,
          vout: transactionOutputModel.vout,
          value: transactionOutputModel.value,
          labels: labels,
          scriptPubkey: transactionOutputModel.scriptPubkey,
          address: transactionOutputModel.address,
          addressLabels: addressLabels,
          isFrozen: isFrozen,
        );
      case LiquidTransactionOutputModel _:
        return TransactionOutput.liquid(
          txId: transactionOutputModel.txId,
          vout: transactionOutputModel.vout,
          value: transactionOutputModel.value,
          labels: labels,
          scriptPubkey: transactionOutputModel.scriptPubkey,
          standardAddress: transactionOutputModel.standardAddress,
          confidentialAddress: transactionOutputModel.confidentialAddress,
          addressLabels: addressLabels,
          isFrozen: isFrozen,
        );
    }
  }
}
