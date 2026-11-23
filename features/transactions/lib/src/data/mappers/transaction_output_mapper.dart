import 'package:transactions/src/data/models/transaction_output_model.dart';
import 'package:transactions/src/domain/entities/transaction_output.dart';
import 'package:labels/labels.dart';

class TransactionOutputMapper {
  static TransactionOutputModel fromEntity(
    TransactionOutput transactionOutput,
  ) {
    switch (transactionOutput) {
      case BitcoinTransactionOutput _:
        return TransactionOutputModel.bitcoin(
          txId: transactionOutput.txId,
          vout: transactionOutput.vout,
          isOwn: transactionOutput.isOwn,
          value: transactionOutput.value,
          scriptPubkey: transactionOutput.scriptPubkey,
          address: transactionOutput.address,
          isChange: transactionOutput.isChange,
        );
      case LiquidTransactionOutput _:
        return TransactionOutputModel.liquid(
          txId: transactionOutput.txId,
          vout: transactionOutput.vout,
          isOwn: transactionOutput.isOwn,
          value: transactionOutput.value,
          scriptPubkey: transactionOutput.scriptPubkey,
          address: transactionOutput.address,
          isChange: transactionOutput.isChange,
        );
    }
  }

  static TransactionOutput toEntity(
    TransactionOutputModel transactionOutputModel, {
    List<Label> labels = const [],
    List<Label> addressLabels = const [],
  }) {
    switch (transactionOutputModel) {
      case BitcoinTransactionOutputModel _:
        return TransactionOutput.bitcoin(
          txId: transactionOutputModel.txId,
          vout: transactionOutputModel.vout,
          isOwn: transactionOutputModel.isOwn,
          value: transactionOutputModel.value,
          labels: labels,
          scriptPubkey: transactionOutputModel.scriptPubkey,
          address: transactionOutputModel.address,
          isChange: transactionOutputModel.isChange,
          addressLabels: addressLabels,
        );
      case LiquidTransactionOutputModel _:
        return TransactionOutput.liquid(
          txId: transactionOutputModel.txId,
          vout: transactionOutputModel.vout,
          isOwn: transactionOutputModel.isOwn,
          value: transactionOutputModel.value,
          labels: labels,
          scriptPubkey: transactionOutputModel.scriptPubkey,
          address: transactionOutputModel.address,
          isChange: transactionOutputModel.isChange,
          addressLabels: addressLabels,
        );
    }
  }
}
