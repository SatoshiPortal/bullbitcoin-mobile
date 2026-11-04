import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction_output.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class TransactionOutputMapper {
  static TransactionOutput toEntity(
    TransactionOutputDetails transactionOutputModel, {
    List<Label> labels = const [],
    List<Label> addressLabels = const [],
  }) {
    switch (transactionOutputModel) {
      case BitcoinTransactionOutputDetails _:
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
      case LiquidTransactionOutputDetails _:
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
