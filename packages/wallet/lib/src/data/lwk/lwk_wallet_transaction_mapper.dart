import '../models/wallet_transaction_model.dart';
import '../models/transaction_input_model.dart';
import '../models/transaction_output_model.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:bull_sdk/lwk.dart' as lwk;

WalletTransaction mapLwkTransaction(
  lwk.Tx transaction, {
  required String lbtcAssetId,
  Set<String> externalAddresses = const {},
}) {
  final lbtcBalance = transaction.balances
      .where((balance) => balance.assetId == lbtcAssetId)
      .fold<int>(0, (sum, balance) => sum + _int(balance.value));
  final displayBalance =
      transaction.balances
          .where((balance) => balance.assetId == lbtcAssetId)
          .map((balance) => _int(balance.value))
          .firstOrNull ??
      0;
  final displaySelfTransfer =
      transaction.kind == 'redeposit' ||
      displayBalance.abs() == _int(transaction.fee);
  // The installed SDK filters unknown entries. Input positions and total
  // slot counts cannot be reconstructed from these lists.
  final outputs = [
    for (final output in transaction.outputs)
      _output(output, externalAddresses, displaySelfTransfer),
  ];
  final inputs = [
    for (final input in transaction.inputs)
      _input(input, externalAddresses, displaySelfTransfer),
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
    displayAmountSats: liquidTransactionAmountSat(
      isToSelf: displaySelfTransfer,
      isIncoming: transaction.kind == 'incoming',
      finalBalance: displayBalance,
      feeSat: _int(transaction.fee),
      lbtcAssetId: lbtcAssetId,
      outputs: transaction.outputs,
      externalAddresses: externalAddresses,
    ),
    displaySelfTransfer: displaySelfTransfer,
    isRbf: false,
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

TransactionInput _input(
  lwk.TxOut value,
  Set<String> externalAddresses,
  bool displaySelfTransfer,
) => TransactionInput(
  txid: value.outpoint.txid,
  isOwn:
      displaySelfTransfer ||
      externalAddresses.contains(value.address.standard) ||
      externalAddresses.contains(value.address.confidential),
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

TransactionOutput _output(
  lwk.TxOut value,
  Set<String> externalAddresses,
  bool displaySelfTransfer,
) => TransactionOutput(
  valueSats: _int(value.unblinded.value),
  txid: value.outpoint.txid,
  isOwn:
      displaySelfTransfer ||
      externalAddresses.contains(value.address.standard) ||
      externalAddresses.contains(value.address.confidential),
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

/// The legacy foreground projection uses the same ownership and amount evidence
/// as snapshots. The exact-detail URL is read only on explicit request and never
/// becomes part of the normalized observation.
WalletTransactionModel mapLwkTransactionDetails(
  lwk.Tx transaction, {
  required String lbtcAssetId,
  required Set<String> externalAddresses,
  required bool isTestnet,
  bool includeUnblindedUrl = false,
}) {
  final observation = mapLwkTransaction(
    transaction,
    lbtcAssetId: lbtcAssetId,
    externalAddresses: externalAddresses,
  );
  final amount = observation.displayAmountSats;
  if (amount == null) {
    throw StateError('LWK display amount is missing');
  }
  return WalletTransactionModel(
    txId: transaction.txid,
    isIncoming: transaction.kind == 'incoming',
    amountSat: amount,
    feeSat: observation.feeSats,
    vsize: transaction.vsize.toInt(),
    confirmationTimestamp: transaction.timestamp,
    isToSelf: observation.displaySelfTransfer == true,
    inputs: [
      for (final (index, input) in transaction.inputs.indexed)
        TransactionInputModel.liquid(
          txId: transaction.txid,
          vin: index,
          isOwn: observation.inputs[index].isOwn == true,
          value: input.unblinded.value,
          scriptPubkey: input.scriptPubkey,
          previousTxId: input.outpoint.txid,
          previousTxVout: input.outpoint.vout,
        ),
    ],
    outputs: [
      for (final (index, output) in transaction.outputs.indexed)
        TransactionOutputModel.liquid(
          txId: transaction.txid,
          vout: output.outpoint.vout,
          isOwn: observation.outputs[index].isOwn == true,
          value: output.unblinded.value,
          scriptPubkey: output.scriptPubkey,
          address: output.address.confidential,
        ),
    ],
    isLiquid: true,
    isTestnet: isTestnet,
    unblindedUrl: includeUnblindedUrl ? transaction.unblindedUrl : null,
    isRbf: false,
  );
}

int liquidTransactionAmountSat({
  required bool isToSelf,
  required bool isIncoming,
  required int finalBalance,
  required int feeSat,
  required String lbtcAssetId,
  required List<lwk.TxOut> outputs,
  required Set<String> externalAddresses,
}) {
  if (isToSelf) {
    return outputs
        .where(
          (output) =>
              output.unblinded.asset == lbtcAssetId &&
              (externalAddresses.contains(output.address.standard) ||
                  externalAddresses.contains(output.address.confidential)),
        )
        .fold(0, (sum, output) => sum + output.unblinded.value.toInt());
  }
  return isIncoming ? finalBalance : finalBalance.abs() - feeSat;
}
