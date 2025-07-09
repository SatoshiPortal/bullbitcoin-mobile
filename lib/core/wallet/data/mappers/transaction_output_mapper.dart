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
          isOwn: transactionOutput.isOwn,
          value: transactionOutput.value,
          scriptPubkey: transactionOutput.scriptPubkey,
          address: transactionOutput.address,
        );
      case LiquidTransactionOutput _:
        return TransactionOutputModel.liquid(
          txId: transactionOutput.txId,
          vout: transactionOutput.vout,
          isOwn: transactionOutput.isOwn,
          value: transactionOutput.value,
          scriptPubkey: transactionOutput.scriptPubkey,
          address: transactionOutput.address,
        );
    }
  }

  static TransactionOutput toEntity(
    TransactionOutputModel transactionOutputModel, {
    List<String> labels = const [],
    List<String> addressLabels = const [],
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
          addressLabels: addressLabels,
        );
    }
  }
}
