import 'package:bb_mobile/features/transactions/domain/entities/transaction_input.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction_output.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/transactions/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class WalletTransactionMapper {
  static WalletTransaction toEntity(
    WalletTransactionDetails walletTransactionModel, {
    required String walletId,
    required List<TransactionInput> inputs,
    required List<TransactionOutput> outputs,
    List<Label>? labels,
    required bool isRbf,
  }) {
    final timestamp = walletTransactionModel.confirmationTimestamp;
    return WalletTransaction(
      walletId: walletId,
      network: Network.fromEnvironment(
        isTestnet: walletTransactionModel.isTestnet,
        isLiquid: walletTransactionModel.isLiquid,
      ),
      direction: walletTransactionModel.isIncoming
          ? WalletTransactionDirection.incoming
          : WalletTransactionDirection.outgoing,
      status: walletTransactionModel.confirmationTimestamp == null
          ? WalletTransactionStatus.pending
          : WalletTransactionStatus.confirmed,
      txId: walletTransactionModel.txId,
      amountSat: walletTransactionModel.amountSat,
      feeSat: walletTransactionModel.feeSat,
      confirmationTime: timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
          : null,
      isToSelf: walletTransactionModel.isToSelf,
      labels: labels ?? [],
      inputs: inputs,
      outputs: outputs,
      unblindedUrl: walletTransactionModel.unblindedUrl,
      isRbf: isRbf,
      vsize: walletTransactionModel.vsize,
    );
  }
}
