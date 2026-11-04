import '../models/wallet_transaction_model.dart';
import '../models/transaction_input_model.dart';
import '../models/transaction_output_model.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

List<WalletTransaction> mapBdkTransactions(
  bdk.Wallet wallet, {
  required bool isTestnet,
}) {
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
        isTestnet: isTestnet,
      ),
  ];
}

WalletTransaction mapBdkTransaction(
  bdk.Wallet wallet,
  bdk.CanonicalTx canonical, {
  required Map<String, bdk.LocalOutput> outputsByOutpoint,
  required bool isTestnet,
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
      isOwn: outputsByOutpoint.containsKey(
        '${input.previousOutput.txid}:${input.previousOutput.vout}',
      ),
      scriptSig: _hex(input.scriptSig.toBytes()),
    );
  }).toList();
  final outputs = transaction.output().asMap().entries.map((entry) {
    final output = entry.value;
    final owned = outputsByOutpoint['$txid:${entry.key}'];
    String? address;
    try {
      address = bdk.Address.fromScript(
        script: output.scriptPubkey,
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      ).toString();
    } catch (_) {
      // OP_RETURN and other non-address scripts have no address.
    }
    return TransactionOutput(
      valueSats: output.value.toSat(),
      txid: txid,
      vout: entry.key,
      script: _hex(output.scriptPubkey.toBytes()),
      originalIndex: entry.key,
      standardAddress: address,
      isOwn: wallet.isMine(script: output.scriptPubkey),
      chain: owned == null
          ? null
          : owned.keychain == bdk.KeychainKind.internal
          ? TransactionChain.internal
          : TransactionChain.external,
    );
  }).toList();
  // Keep the observation's signed balance delta and payment classification.
  // The UI's established projection uses destination amounts for self-sends.
  final displaySelfTransfer =
      inputs.every((input) => input.isOwn == true) &&
      outputs.every((output) => output.isOwn == true);
  final destinationAmount = outputs
      .where((output) => output.chain != TransactionChain.internal)
      .fold(0, (sum, output) => sum + output.valueSats);
  final displayAmount = bitcoinDisplayAmount(
    isToSelf: displaySelfTransfer,
    sent: sent,
    received: received,
    fee: fee,
    destination: destinationAmount,
  );

  return WalletTransaction(
    txid: txid,
    amountSats: received - sent,
    feeSats: fee,
    displayAmountSats: evidence['feeUnavailable'] == true
        ? null
        : displayAmount,
    displaySelfTransfer: displaySelfTransfer,
    isRbf: transaction.isExplicitlyRbf(),
    vsize: transaction.vsize(),
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
    transactions: mapBdkTransactions(
      wallet,
      isTestnet:
          (registration.configuration as BdkElectrumConfiguration).isTestnet,
    ),
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

/// Projects a native transaction using the foreground's selected prevouts.
/// Fee extraction deliberately still throws when BDK cannot establish it.
WalletTransactionModel mapBdkTransactionDetails(
  bdk.Wallet wallet,
  bdk.CanonicalTx canonical, {
  required bool isTestnet,
  required List<TransactionInputModel> inputs,
  required List<BitcoinTransactionOutputModel> outputs,
}) {
  final transaction = canonical.transaction;
  final balance = wallet.sentAndReceived(tx: transaction);
  final received = balance.received.toSat();
  final sent = balance.sent.toSat();
  final fee = wallet.calculateFee(tx: transaction).toSat();
  final isToSelf =
      inputs.every((input) => input.isOwn) &&
      outputs.every((output) => output.isOwn);
  final destination = outputs
      .where((output) => !output.isChange)
      .fold(0, (sum, output) => sum + (output.value?.toInt() ?? 0));
  final position = canonical.chainPosition;
  return WalletTransactionModel(
    txId: transaction.computeTxid().toString(),
    isIncoming: received > sent,
    amountSat: bitcoinDisplayAmount(
      isToSelf: isToSelf,
      sent: sent,
      received: received,
      fee: fee,
      destination: destination,
    ),
    feeSat: fee,
    vsize: transaction.vsize(),
    confirmationTimestamp: position is bdk.ConfirmedChainPosition
        ? position.confirmationBlockTime.confirmationTime
        : null,
    isToSelf: isToSelf,
    inputs: inputs,
    outputs: outputs,
    isLiquid: false,
    isTestnet: isTestnet,
    isRbf: transaction.isExplicitlyRbf(),
  );
}

int bitcoinDisplayAmount({
  required bool isToSelf,
  required int sent,
  required int received,
  required int fee,
  required int destination,
}) {
  if (isToSelf) return destination > 0 ? destination : fee;
  return received > sent ? received - sent : sent - received - fee;
}
