import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/application/ports/transaction_export_formatter.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';

class CsvTransactionExportFormatter implements TransactionExportFormatter {
  static const _headers = [
    'date',
    'type',
    'direction',
    'amount_sats',
    'amount_btc',
    'fee_sats',
    'status',
    'txid',
    'network',
    'address',
    'swap_id',
    'invoice',
    'preimage',
    'swap_fee_sats',
    'send_network',
    'receive_network',
    'send_txid',
    'receive_txid',
  ];

  @override
  String format(List<Transaction> transactions) {
    final buffer = StringBuffer()..writeln(_headers.join(','));
    for (final tx in transactions) {
      buffer.writeln(_row(tx).map(_escape).join(','));
    }
    return buffer.toString();
  }

  List<String> _row(Transaction tx) {
    final swap = tx.swap;
    final isChainSwap = swap?.isChainSwap ?? false;
    final isLightning =
        (swap?.isLnSendSwap ?? false) || (swap?.isLnReceiveSwap ?? false);
    final amountSat = tx.amountSat;
    // fee is only paid by the sender; incoming txs show 0
    final feeSat = tx.isIncoming ? 0 : (tx.walletTransaction?.feeSat ?? 0);

    return [
      _date(tx.timestamp),
      _type(tx),
      _direction(tx),
      amountSat.toString(),
      _btc(amountSat),
      feeSat.toString(),
      _status(tx),
      tx.txId ?? '',
      isChainSwap ? _chainNetwork(swap!, send: true) : (tx.isBitcoin ? 'bitcoin' : 'liquid'),
      isLightning ? '' : isChainSwap ? (swap?.receiveAddress ?? '') : (tx.toAddress ?? ''),
      swap?.id ?? '',
      _invoice(swap),
      _preimage(swap),
      swap?.fees?.totalFees(swap.amountSat).toString() ?? '',
      isChainSwap ? _chainNetwork(swap!, send: true) : '',
      isChainSwap ? _chainNetwork(swap!, send: false) : '',
      swap?.sendTxId ?? '',
      swap?.receiveTxId ?? '',
    ];
  }

  String _date(DateTime? timestamp) {
    if (timestamp == null) return '';
    return '${timestamp.toUtc().toIso8601WithoutMilliseconds()}Z';
  }

  String _type(Transaction tx) {
    if (tx.isPayjoin) {
      return tx.payjoin is PayjoinSender ? 'payjoin_send' : 'payjoin_receive';
    }
    final swap = tx.swap;
    if (swap != null) {
      if (swap.isLnSendSwap) return 'lightning_send';
      if (swap.isLnReceiveSwap) return 'lightning_receive';
      if (swap.isChainSwap) return 'chain_swap';
    }
    return tx.isBitcoin ? 'onchain' : 'liquid';
  }

  String _direction(Transaction tx) {
    if (tx.walletTransaction?.isToSelf ?? false) return 'self';
    if (tx.isIncoming) return 'incoming';
    if (tx.isOutgoing) return 'outgoing';
    return '';
  }

  String _status(Transaction tx) {
    final wt = tx.walletTransaction;
    if (wt != null) {
      switch (wt.status) {
        case WalletTransactionStatus.pending:
          return 'pending';
        case WalletTransactionStatus.confirmed:
          return 'confirmed';
      }
    }
    final swap = tx.swap;
    if (swap != null) {
      switch (swap.status) {
        case SwapStatus.pending:
        case SwapStatus.paid:
        case SwapStatus.claimable:
        case SwapStatus.refundable:
        case SwapStatus.canCoop:
          return 'pending';
        case SwapStatus.completed:
          return 'completed';
        case SwapStatus.expired:
          return 'expired';
        case SwapStatus.failed:
          return 'failed';
      }
    }
    final payjoin = tx.payjoin;
    if (payjoin != null) {
      switch (payjoin.status) {
        case PayjoinStatus.started:
        case PayjoinStatus.requested:
        case PayjoinStatus.proposed:
          return 'pending';
        case PayjoinStatus.completed:
          return 'completed';
        case PayjoinStatus.expired:
          return 'expired';
      }
    }
    return '';
  }

  String _btc(int sats) => (sats / 100000000).toStringAsFixed(8);

  String _invoice(Swap? swap) => switch (swap) {
    LnReceiveSwap(:final invoice) => invoice,
    LnSendSwap(:final invoice) => invoice,
    _ => '',
  };

  String _preimage(Swap? swap) => switch (swap) {
    LnSendSwap(:final preimage) => preimage ?? '',
    _ => '',
  };

  String _chainNetwork(Swap swap, {required bool send}) {
    final toLiquid = swap.type == SwapType.bitcoinToLiquid;
    if (send) return toLiquid ? 'bitcoin' : 'liquid';
    return toLiquid ? 'liquid' : 'bitcoin';
  }

  String _escape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
