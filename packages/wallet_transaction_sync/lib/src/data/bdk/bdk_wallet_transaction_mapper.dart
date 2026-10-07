import 'package:bull_sdk/bdk.dart' as bdk;

import '../../domain/entities/transaction_input.dart';
import '../../domain/entities/transaction_output.dart';
import '../../domain/entities/transaction_position.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/entities/wallet_transaction_observation.dart';
import '../../domain/entities/wallet_source_observation.dart';
import '../../domain/wallet_source_registration.dart';

List<WalletTransaction> mapBdkTransactions(bdk.Wallet wallet) {
  final transactions = wallet.transactions();
  final outputsByOutpoint = <String, bdk.LocalOutput>{
    for (final output in wallet.listOutput())
      '${output.outpoint.txid}:${output.outpoint.vout}': output,
  };
  return [
    for (final canonical in transactions)
      mapBdkTransaction(
        wallet,
        canonical,
        outputsByOutpoint: outputsByOutpoint,
      ),
  ];
}

WalletTransaction mapBdkTransaction(
  bdk.Wallet wallet,
  bdk.CanonicalTx canonical, {
  required Map<String, bdk.LocalOutput> outputsByOutpoint,
}) {
  final transaction = canonical.transaction;
  final txid = transaction.computeTxid().toString();
  final sentAndReceived = wallet.sentAndReceived(tx: transaction);
  final received = sentAndReceived.received.toSat();
  final sent = sentAndReceived.sent.toSat();
  var fee = 0;
  final evidence = <String, Object?>{};
  try {
    fee = wallet.calculateFee(tx: transaction).toSat();
  } catch (_) {
    evidence['feeUnavailable'] = true;
  }
  final selfTransfer = sent > 0 && received > 0 && sent - received == fee;

  final inputs = transaction.input().asMap().entries.map((entry) {
    final input = entry.value;
    return TransactionInput(
      txid: input.previousOutput.txid.toString(),
      vout: input.previousOutput.vout,
      originalIndex: entry.key,
    );
  }).toList();
  final outputs = transaction
      .output()
      .asMap()
      .entries
      .map(
        (entry) => TransactionOutput(
          valueSats: entry.value.value.toSat(),
          txid: txid,
          vout: entry.key,
          script: _hex(entry.value.scriptPubkey.toBytes()),
          originalIndex: entry.key,
        ),
      )
      .toList();

  return WalletTransaction(
    txid: txid,
    amountSats: received - sent,
    feeSats: fee,
    inputs: inputs,
    outputs: outputs,
    position: _position(canonical.chainPosition),
    direction: received > sent
        ? TransactionDirection.incoming
        : sent > received
        ? TransactionDirection.outgoing
        : null,
    selfTransfer: selfTransfer,
    evidence: evidence,
    details: {
      'ownedInputCount': inputs
          .where(
            (input) =>
                outputsByOutpoint.containsKey('${input.txid}:${input.vout}'),
          )
          .length,
    },
  );
}

WalletSourceObservation mapBdkObservation(
  bdk.Wallet wallet, {
  required WalletSourceRegistration registration,
  required bool networkOperation,
  required bool discover,
}) {
  final checkpoint = wallet.latestCheckpoint();
  final capabilities = <String>{'electrum'};
  if (discover) capabilities.add('fullScan');
  return WalletSourceObservation(
    key: registration.key,
    registration: registration,
    transactions: mapBdkTransactions(wallet),
    capabilities: capabilities,
    sourceTip: '${checkpoint.height}:${checkpoint.hash}',
    evidenceLevel: networkOperation
        ? WalletEvidenceLevel.walletSourceReported
        : WalletEvidenceLevel.localSourceState,
  );
}

TransactionPosition _position(bdk.ChainPosition position) => switch (position) {
  bdk.ConfirmedChainPosition(:final confirmationBlockTime) => AnchoredPosition(
    confirmationBlockTime.blockId.hash.toString(),
    confirmationBlockTime.blockId.height,
    DateTime.fromMillisecondsSinceEpoch(
      confirmationBlockTime.confirmationTime * 1000,
      isUtc: true,
    ),
  ),
  // The time must come from source data, never from the observation clock:
  // injecting `observedAt` here would change the content fingerprint on
  // every refresh of an identical wallet state.
  bdk.UnconfirmedChainPosition(:final timestamp) =>
    timestamp == null
        ? const UnknownPosition()
        : UnconfirmedPosition(
            DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true),
            DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true),
          ),
  _ => const UnknownPosition(),
};

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
