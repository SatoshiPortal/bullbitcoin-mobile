import 'package:bull_sdk/lwk.dart' as lwk;

import '../../domain/entities/transaction_input.dart';
import '../../domain/entities/transaction_output.dart';
import '../../domain/entities/transaction_chain.dart';
import '../../domain/entities/transaction_position.dart';
import '../../domain/entities/wallet_transaction.dart';

WalletTransaction mapLwkTransaction(
  lwk.Tx transaction, {
  required String lbtcAssetId,
  Set<String> externalAddresses = const {},
}) {
  final lbtcBalance = transaction.balances
      .where((balance) => balance.assetId == lbtcAssetId)
      .fold<int>(0, (sum, balance) => sum + _int(balance.value));
  // The installed SDK filters unknown entries. Input positions and total
  // slot counts cannot be reconstructed from these lists.
  final outputs = [
    for (final output in transaction.outputs)
      _output(output, externalAddresses),
  ];
  final inputs = [
    for (final input in transaction.inputs) _input(input, externalAddresses),
  ];
  final kind = transaction.kind.toLowerCase();
  final incoming = kind == 'incoming';
  final selfTransfer =
      kind == 'redeposit' ||
      (!incoming && lbtcBalance.abs() == _int(transaction.fee));
  final amount = selfTransfer
      ? outputs
            .where(
              (output) =>
                  output.assetId == lbtcAssetId &&
                  output.chain == TransactionChain.external,
            )
            .fold<int>(0, (sum, output) => sum + output.valueSats)
      : incoming
      ? lbtcBalance
      : lbtcBalance.abs() - _int(transaction.fee);
  return WalletTransaction(
    txid: transaction.txid,
    amountSats: amount,
    feeSats: _int(transaction.fee),
    inputs: inputs,
    outputs: outputs,
    direction: incoming
        ? TransactionDirection.incoming
        : TransactionDirection.outgoing,
    selfTransfer: selfTransfer,
    vsize: _int(transaction.vsize),
    position: _position(transaction.height, transaction.timestamp),
  );
}

TransactionInput _input(lwk.TxOut value, Set<String> externalAddresses) =>
    TransactionInput(
      txid: value.outpoint.txid,
      vout: value.outpoint.vout,
      value: _int(value.unblinded.value),
      assetId: value.unblinded.asset,
      script: value.scriptPubkey,
      standardAddress: value.address.standard,
      confidentialAddress: value.address.confidential,
      height: value.height,
      isSpent: value.isSpent,
      chain:
          externalAddresses.contains(value.address.standard) ||
              externalAddresses.contains(value.address.confidential)
          ? TransactionChain.external
          : null,
    );

TransactionOutput _output(lwk.TxOut value, Set<String> externalAddresses) =>
    TransactionOutput(
      valueSats: _int(value.unblinded.value),
      txid: value.outpoint.txid,
      vout: value.outpoint.vout,
      originalIndex: value.outpoint.vout,
      assetId: value.unblinded.asset,
      script: value.scriptPubkey,
      standardAddress: value.address.standard,
      confidentialAddress: value.address.confidential,
      height: value.height,
      isSpent: value.isSpent,
      chain:
          externalAddresses.contains(value.address.standard) ||
              externalAddresses.contains(value.address.confidential)
          ? TransactionChain.external
          : null,
    );

TransactionPosition _position(int? height, int? timestamp) {
  final time = timestamp == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
  if (height != null) return SourceReportedConfirmedPosition(height, time);
  if (time != null) return UnconfirmedPosition(time, time);
  return const UnknownPosition();
}

int _int(Object value) =>
    value is BigInt ? value.toInt() : (value as num).toInt();
