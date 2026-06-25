import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/view_models/transaction_detail_view_model.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/contributors/transaction_section_contributor.dart';
import 'package:bb_mobile/features/transactions/utils/tx_format.dart';

/// Plain on-chain Bitcoin/Liquid sends and receives. Composes under payjoin
/// (a broadcasted payjoin is also a wallet transaction), but never applies to
/// swaps or orders — those mechanisms own their full presentation so there is
/// only ever one status.
class OnchainSectionContributor extends TransactionSectionContributor {
  const OnchainSectionContributor();

  @override
  int get priority => 0;

  @override
  bool appliesTo(Transaction tx) =>
      tx.walletTransaction != null && !tx.isSwap && !tx.isOrder;

  @override
  TxHeaderView? header(Transaction tx, TxPresentDeps deps) {
    return TxHeaderView(
      isIncoming: tx.isIncoming,
      isTransfer: false,
      statusLabel: tx.isIncoming
          ? deps.loc.transactionFilterReceive
          : deps.loc.transactionFilterSend,
      amount: TxAmountView(sats: tx.amountSat),
    );
  }

  @override
  List<TxDetailRow> rows(Transaction tx, TxPresentDeps deps) {
    final loc = deps.loc;
    final wtx = tx.walletTransaction!;
    final txId = tx.txId;
    final toAddress = tx.toAddress;
    final labels = tx.labels ?? [];
    final addressLabels = wtx.toAddressLabels ?? [];

    return [
      if (txId != null)
        TxDetailRow(
          label: loc.transactionDetailLabelTransactionId,
          value: TxId(
            txId,
            isLiquid: tx.isLiquid,
            isTestnet: tx.isTestnet,
            unblindedUrl: wtx.unblindedUrl,
          ),
          copyValue: txId,
        ),
      if (labels.isNotEmpty && txId != null)
        TxDetailRow(
          label: loc.transactionNotesLabel,
          value: TxLabels(labels),
        ),
      if (deps.walletLabel.isNotEmpty)
        TxDetailRow(
          label: tx.isIncoming
              ? loc.transactionDetailLabelToWallet
              : loc.transactionDetailLabelFromWallet,
          value: TxText(deps.walletLabel),
        ),
      if (deps.counterpartWalletLabel.isNotEmpty)
        TxDetailRow(
          label: tx.isOutgoing
              ? loc.transactionDetailLabelToWallet
              : loc.transactionDetailLabelFromWallet,
          value: TxText(deps.counterpartWalletLabel),
        ),
      if (toAddress != null)
        TxDetailRow(
          label: loc.transactionDetailLabelAddress,
          value: TxAddress(toAddress),
          copyValue: toAddress,
        ),
      if (addressLabels.isNotEmpty && toAddress != null)
        TxDetailRow(
          label: loc.transactionDetailLabelAddressNotes,
          value: TxLabels(addressLabels),
        ),
      TxDetailRow(
        label: tx.isIncoming
            ? loc.transactionDetailLabelAmountReceived
            : loc.transactionDetailLabelAmountSent,
        value: TxAmount(tx.isIncoming ? deps.amountReceived : deps.amountSent),
      ),
      if (wtx.isToSelf)
        TxDetailRow(
          label: loc.transactionDetailLabelAmountReceived,
          value: TxAmount(deps.amountReceived),
        ),
      if (tx.isOutgoing)
        TxDetailRow(
          label: loc.transactionDetailLabelTransactionFee,
          value: TxAmount(wtx.feeSat),
        ),
      TxDetailRow(
        label: loc.transactionDetailLabelStatus,
        value: TxText(wtx.status.displayName(loc)),
      ),
      if (wtx.confirmationTime != null)
        TxDetailRow(
          label: loc.transactionDetailLabelConfirmationTime,
          value: TxText(formatTxDate(wtx.confirmationTime!)),
        ),
    ];
  }
}
