import 'package:bull_sdk/lwk.dart' as lwk;

import '../../domain/entities/transaction_input.dart';
import '../../domain/entities/transaction_output.dart';
import '../../domain/entities/transaction_chain.dart';
import '../../domain/entities/transaction_position.dart';
import '../../domain/entities/wallet_transaction.dart';

WalletTransaction mapLwkTransaction(
  lwk.WalletTxProjection projection, {
  required String lbtcAssetId,
}) {
  final lbtcBalance = projection.balances
      .where((balance) => balance.assetId == lbtcAssetId)
      .fold<int>(0, (sum, balance) => sum + _int(balance.value));
  final outputs = <TransactionOutput>[];
  for (var index = 0; index < projection.outputs.length; index++) {
    final output = projection.outputs[index];
    if (output == null) continue;
    outputs.add(_output(output, index));
  }
  final inputs = <TransactionInput>[];
  for (var index = 0; index < projection.inputs.length; index++) {
    final input = projection.inputs[index];
    if (input == null) continue;
    inputs.add(_input(input, index));
  }
  final kind = projection.kind.toLowerCase();
  final incoming = kind == 'incoming';
  final selfTransfer =
      kind == 'redeposit' || lbtcBalance.abs() == _int(projection.fee);
  final amount = selfTransfer
      ? outputs
            .where(
              (output) =>
                  output.assetId == lbtcAssetId &&
                  output.chain != TransactionChain.internal,
            )
            .fold<int>(0, (sum, output) => sum + output.valueSats)
      : incoming
      ? lbtcBalance
      : lbtcBalance.abs() - _int(projection.fee);
  return WalletTransaction(
    txid: projection.txid,
    amountSats: amount,
    feeSats: _int(projection.fee),
    inputs: inputs,
    outputs: outputs,
    inputCount: projection.inputs.length,
    outputCount: projection.outputs.length,
    direction: incoming
        ? TransactionDirection.incoming
        : TransactionDirection.outgoing,
    selfTransfer: selfTransfer,
    vsize: _int(projection.vsize),
    position: _position(projection.height, projection.timestamp),
  );
}

TransactionInput _input(lwk.WalletTxOutCompact value, int index) =>
    TransactionInput(
      txid: value.outpoint.txid,
      vout: value.outpoint.vout,
      originalIndex: index,
      value: _int(value.value),
      assetId: value.asset,
      script: value.scriptPubkey,
      standardAddress: value.standardAddress,
      confidentialAddress: value.confidentialAddress,
      height: value.height,
      isSpent: value.isSpent,
      chain: value.chain == lwk.WalletTxChain.internal
          ? TransactionChain.internal
          : TransactionChain.external,
    );

TransactionOutput _output(lwk.WalletTxOutCompact value, int index) =>
    TransactionOutput(
      valueSats: _int(value.value),
      txid: value.outpoint.txid,
      vout: value.outpoint.vout,
      originalIndex: index,
      assetId: value.asset,
      script: value.scriptPubkey,
      standardAddress: value.standardAddress,
      confidentialAddress: value.confidentialAddress,
      height: value.height,
      isSpent: value.isSpent,
      chain: value.chain == lwk.WalletTxChain.internal
          ? TransactionChain.internal
          : TransactionChain.external,
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
