import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/view_models/transaction_detail_view_model.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/contributors/transaction_section_contributor.dart';
import 'package:bb_mobile/features/transactions/utils/tx_format.dart';

/// Payjoin. Composes on top of [OnchainSectionContributor] once the payjoin is
/// broadcasted (it is then also a wallet transaction); while still ongoing it
/// supplies the identity rows itself.
class PayjoinSectionContributor extends TransactionSectionContributor {
  const PayjoinSectionContributor();

  @override
  int get priority => 20;

  @override
  bool appliesTo(Transaction tx) => tx.isPayjoin;

  bool _isCompleted(Transaction tx) {
    final payjoin = tx.payjoin!;
    return payjoin.isCompleted ||
        (payjoin.status == PayjoinStatus.proposed &&
            tx.walletTransaction != null);
  }

  @override
  TxHeaderView? header(Transaction tx, TxPresentDeps deps) {
    return TxHeaderView(
      isIncoming: tx.isIncoming,
      isTransfer: false,
      statusLabel: _isCompleted(tx)
          ? deps.loc.transactionStatusPayjoinCompleted
          : deps.loc.transactionStatusPayjoinRequested,
      amount: TxAmountView(sats: tx.amountSat),
    );
  }

  @override
  List<TxDetailRow> rows(Transaction tx, TxPresentDeps deps) {
    final loc = deps.loc;
    final payjoin = tx.payjoin!;
    final hasWalletTx = tx.walletTransaction != null;
    final txId = tx.txId;

    return [
      // When still ongoing there is no wallet transaction facet, so supply the
      // core identity rows here; once broadcasted the onchain contributor does.
      if (!hasWalletTx && txId != null)
        TxDetailRow(
          label: loc.transactionDetailLabelTransactionId,
          value: TxId(txId, isLiquid: tx.isLiquid, isTestnet: tx.isTestnet),
          copyValue: txId,
        ),
      if (!hasWalletTx)
        TxDetailRow(
          label: tx.isIncoming
              ? loc.transactionDetailLabelAmountReceived
              : loc.transactionDetailLabelAmountSent,
          value: TxAmount(
            tx.isIncoming ? deps.amountReceived : deps.amountSent,
          ),
        ),
      TxDetailRow(
        label: loc.transactionDetailLabelPayjoinStatus,
        value: TxText(
          _isCompleted(tx)
              ? loc.transactionDetailLabelPayjoinCompleted
              : payjoin.isExpired
              ? loc.transactionDetailLabelPayjoinExpired
              : payjoin.status.name,
        ),
      ),
      TxDetailRow(
        label: loc.transactionDetailLabelPayjoinCreationTime,
        value: TxText(formatTxDate(payjoin.createdAt)),
      ),
    ];
  }
}
