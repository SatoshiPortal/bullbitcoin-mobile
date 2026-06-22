import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/models/transaction_detail_view.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/onchain_section_contributor.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/order_section_contributor.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/payjoin_section_contributor.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/swap_section_contributor.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/transaction_detail_view_builder.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/transaction_section_contributor.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _builder = TransactionDetailViewBuilder([
  OnchainSectionContributor(),
  SwapSectionContributor(),
  OrderSectionContributor(),
  PayjoinSectionContributor(),
]);

WalletTransaction _walletTx({
  WalletTransactionDirection direction = WalletTransactionDirection.outgoing,
  WalletTransactionStatus status = WalletTransactionStatus.confirmed,
}) {
  return WalletTransaction(
    walletId: 'w1',
    network: Network.bitcoinMainnet,
    direction: direction,
    status: status,
    txId: 'aabbccddeeff00112233445566778899',
    amountSat: 100000,
    feeSat: 250,
    vsize: 140,
    inputs: const <TransactionInput>[],
    outputs: const <TransactionOutput>[],
    isRbf: false,
  );
}

void main() {
  late AppLocalizations loc;

  setUpAll(() async {
    loc = await AppLocalizations.delegate.load(const Locale('en'));
  });

  TxPresentDeps deps({int amountSent = 0, int amountReceived = 0, String? counterpartTxId}) {
    return TxPresentDeps(
      loc: loc,
      amountSent: amountSent,
      amountReceived: amountReceived,
      swapCounterpartTxId: counterpartTxId,
    );
  }

  group('on-chain transaction', () {
    test('renders identity rows and a single status, no progress', () {
      final tx = Transaction(walletTransaction: _walletTx());
      final view = _builder.build(tx, deps(amountSent: 100000));

      expect(view.progress, isNull);
      expect(view.callouts, isEmpty);
      expect(view.header.isTransfer, isFalse);
      // Exactly one status row.
      final statusRows = view.rows.where(
        (r) => r.label == loc.transactionDetailLabelStatus,
      );
      expect(statusRows.length, 1);
    });
  });

  group('ongoing chain swap', () {
    final swap = Swap.chain(
      id: 'swap-123',
      keyIndex: 0,
      type: SwapType.bitcoinToLiquid,
      status: SwapStatus.paid,
      environment: Environment.mainnet,
      creationTime: DateTime.utc(2026, 3, 3, 10),
      sendWalletId: 'w1',
      paymentAddress: 'bc1qsendaddr',
      paymentAmount: 100000,
      sendTxid: 'aabbccddeeff00112233445566778899',
      receiveAddress: 'lq1qrecipient',
      receiveTxid: 'ffeeddccbbaa99887766554433221100',
      fees: const SwapFees(lockupFee: 500, claimFee: 200, boltzFee: 100),
    );

    test('single authoritative status via progress, header agrees', () {
      final tx = Transaction(swap: swap);
      final view = _builder.build(tx, deps(counterpartTxId: 'ffeeddcc'));

      // One status, and it is the progress row — not a second contradicting one.
      expect(view.progress, isNotNull);
      expect(view.progress!.state, TxProgressState.inProgress);
      expect(view.progress!.currentStep, 1);
      expect(view.progress!.steps.length, 4);
      expect(view.header.isTransfer, isTrue);
      expect(view.header.statusLabel, loc.transactionStatusTransferInProgress);
      // Ongoing swap shows the contextual callout.
      expect(view.callouts, isNotEmpty);
    });

    test('intermediary detail is folded behind the transaction-id row', () {
      final tx = Transaction(swap: swap);
      final view = _builder.build(tx, deps(counterpartTxId: 'ffeeddcc'));

      final txIdRow = view.rows.firstWhere(
        (r) => r.label == loc.transactionDetailLabelTransactionId,
      );
      final foldedLabels = txIdRow.expandedRows.map((r) => r.label).toList();
      // Swap id and the counterpart tx id are hidden by default, reachable on expand.
      expect(foldedLabels, contains(loc.transactionDetailLabelTransferId));
      expect(
        foldedLabels,
        anyOf(
          contains(loc.transactionDetailLabelBitcoinTxId),
          contains(loc.transactionDetailLabelLiquidTxId),
        ),
      );
      // Not shown as top-level rows.
      expect(
        view.rows.any((r) => r.label == loc.transactionDetailLabelTransferId),
        isFalse,
      );

      // A single total-fees row with the breakdown folded into it.
      final feeRows = view.rows.where(
        (r) => r.label == loc.transactionDetailLabelTransferFees,
      );
      expect(feeRows.length, 1);
      expect(feeRows.first.expandedRows, isNotEmpty);
    });
  });
}
