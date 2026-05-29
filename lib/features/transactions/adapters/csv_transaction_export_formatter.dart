import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/application/ports/transaction_export_formatter.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';

class _ExportRow {
  const _ExportRow({
    required this.date,
    required this.type,
    required this.direction,
    required this.amountSats,
    required this.amountBtc,
    required this.feeSats,
    required this.status,
    required this.txid,
    required this.network,
    required this.address,
    required this.swapId,
    required this.preimage,
    required this.swapFeeSats,
    required this.sendNetwork,
    required this.receiveNetwork,
    required this.sendTxid,
    required this.receiveTxid,
  });

  final String date;
  final String type;
  final String direction;
  final String amountSats;
  final String amountBtc;
  final String feeSats;
  final String status;
  final String txid;
  final String network;
  final String address;
  final String swapId;
  final String preimage;
  final String swapFeeSats;
  final String sendNetwork;
  final String receiveNetwork;
  final String sendTxid;
  final String receiveTxid;

  List<String> toFields() => [
    date, type, direction, amountSats, amountBtc, feeSats, status, txid,
    network, address, swapId, preimage, swapFeeSats,
    sendNetwork, receiveNetwork, sendTxid, receiveTxid,
  ];
}

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
      buffer.writeln(_normalize(tx).toFields().map(_escape).join(','));
    }
    return buffer.toString();
  }

  _ExportRow _normalize(Transaction tx) {
    final swap = tx.swap;
    final payjoin = tx.payjoin;
    final wt = tx.walletTransaction;

    final isLnSwap = swap?.isLnSendSwap == true || swap?.isLnReceiveSwap == true;
    final isChainSwap = swap?.isChainSwap == true;
    final amountSat = tx.amountSat;
    final feeSat = tx.isIncoming ? 0 : (wt?.feeSat ?? 0);

    final type = _resolveType(tx, swap, payjoin);
    final direction = _resolveDirection(tx, wt);
    final status = _resolveStatus(tx, swap, wt, payjoin);
    final network = _resolveNetwork(tx, swap, isLnSwap, isChainSwap);
    final address = _resolveAddress(tx, swap, isLnSwap, isChainSwap);

    return _ExportRow(
      date: _date(tx.timestamp),
      type: type,
      direction: direction,
      amountSats: amountSat.toString(),
      amountBtc: _btc(amountSat),
      feeSats: feeSat.toString(),
      status: status,
      txid: tx.txId ?? '',
      network: network,
      address: address,
      swapId: swap?.id ?? '',
      preimage: switch (swap) {
        LnSendSwap(:final preimage) => preimage ?? '',
        _ => '',
      },
      swapFeeSats: swap?.fees?.totalFees(swap.amountSat).toString() ?? '',
      sendNetwork: isChainSwap ? _chainNetwork(swap!, send: true) : '',
      receiveNetwork: isChainSwap ? _chainNetwork(swap!, send: false) : '',
      sendTxid: swap?.sendTxId ?? '',
      receiveTxid: swap?.receiveTxId ?? '',
    );
  }

  String _resolveType(Transaction tx, Swap? swap, Payjoin? payjoin) {
    if (payjoin != null) {
      return payjoin is PayjoinSender ? 'payjoin_send' : 'payjoin_receive';
    }
    if (swap != null) {
      if (swap.isLnSendSwap) return 'lightning_send';
      if (swap.isLnReceiveSwap) return 'lightning_receive';
      if (swap.isChainSwap) return 'chain_swap';
    }
    return tx.isBitcoin ? 'onchain' : 'liquid';
  }

  String _resolveDirection(Transaction tx, WalletTransaction? wt) {
    if (wt?.isToSelf ?? false) return 'self';
    if (tx.isIncoming) return 'incoming';
    if (tx.isOutgoing) return 'outgoing';
    return '';
  }

  String _resolveStatus(
    Transaction tx,
    Swap? swap,
    WalletTransaction? wt,
    Payjoin? payjoin,
  ) {
    if (swap != null) {
      return switch (swap.status) {
        SwapStatus.pending ||
        SwapStatus.paid ||
        SwapStatus.claimable ||
        SwapStatus.refundable ||
        SwapStatus.canCoop => 'pending',
        SwapStatus.completed => 'completed',
        SwapStatus.expired => 'expired',
        SwapStatus.failed => 'failed',
      };
    }
    if (wt != null) {
      return switch (wt.status) {
        WalletTransactionStatus.pending => 'pending',
        WalletTransactionStatus.confirmed => 'confirmed',
      };
    }
    if (payjoin != null) {
      return switch (payjoin.status) {
        PayjoinStatus.started ||
        PayjoinStatus.requested ||
        PayjoinStatus.proposed => 'pending',
        PayjoinStatus.completed => 'completed',
        PayjoinStatus.expired => 'expired',
      };
    }
    return '';
  }

  String _resolveNetwork(
    Transaction tx,
    Swap? swap,
    bool isLnSwap,
    bool isChainSwap,
  ) {
    if (isLnSwap) return '';
    if (isChainSwap) return _chainNetwork(swap!, send: true);
    return tx.isBitcoin ? 'bitcoin' : 'liquid';
  }

  String _resolveAddress(
    Transaction tx,
    Swap? swap,
    bool isLnSwap,
    bool isChainSwap,
  ) {
    if (isLnSwap) return '';
    if (isChainSwap) return swap?.receiveAddress ?? '';
    return tx.toAddress ?? '';
  }

  String _chainNetwork(Swap swap, {required bool send}) {
    final toLiquid = swap.type == SwapType.bitcoinToLiquid;
    if (send) return toLiquid ? 'bitcoin' : 'liquid';
    return toLiquid ? 'liquid' : 'bitcoin';
  }

  String _date(DateTime? timestamp) {
    if (timestamp == null) return '';
    return '${timestamp.toUtc().toIso8601WithoutMilliseconds()}Z';
  }

  String _btc(int sats) => (sats / 100000000).toStringAsFixed(8);

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
