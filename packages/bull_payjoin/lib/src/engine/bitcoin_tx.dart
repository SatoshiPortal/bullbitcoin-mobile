import 'dart:typed_data';

import 'package:bull_payjoin/src/domain/payjoin_session.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

final class BitcoinTx {
  final String txid;
  final List<TxInput> inputs;
  final List<TxOutput> outputs;

  const BitcoinTx({
    required this.txid,
    required this.inputs,
    required this.outputs,
  });

  static Future<BitcoinTx> fromBytes(List<int> bytes) async {
    return fromBytesSync(bytes);
  }

  static BitcoinTx fromBytesSync(List<int> bytes) {
    final transaction = bdk.Transaction(
      transactionBytes: Uint8List.fromList(bytes),
    );
    return BitcoinTx(
      txid: transaction.computeTxid().toString(),
      inputs: transaction.input().map((input) {
        return TxInput(
          txid: input.previousOutput.txid.toString(),
          vout: input.previousOutput.vout,
        );
      }).toList(),
      outputs: transaction.output().map((output) {
        return TxOutput(
          value: output.value.toSat(),
          scriptPubkey: output.scriptPubkey.toBytes(),
        );
      }).toList(),
    );
  }

  static Future<BitcoinTx> fromPsbt(String psbtBase64) {
    final psbt = bdk.Psbt(psbtBase64: psbtBase64);
    return fromBytes(psbt.extractTx().serialize());
  }

  static BitcoinTx fromPsbtSync(String psbtBase64) {
    final psbt = bdk.Psbt(psbtBase64: psbtBase64);
    return fromBytesSync(psbt.extractTx().serialize());
  }

  Future<int> getAmountReceived({
    required bool isTestnet,
    required String address,
  }) async {
    var total = 0;
    for (final output in outputs) {
      final outputAddress = bdk.Address.fromScript(
        script: bdk.Script(rawOutputScript: output.scriptPubkey),
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      );
      if (outputAddress.toString() == address) total += output.value;
    }
    return total;
  }
}

final class TxInput {
  final String txid;
  final int vout;

  const TxInput({required this.txid, required this.vout});
}

final class TxOutput {
  final int value;
  final Uint8List scriptPubkey;

  const TxOutput({required this.value, required this.scriptPubkey});
}

PayjoinOwnership? derivePayjoinOwnership({
  required BitcoinTx original,
  required BitcoinTx proposal,
  required Uint8List paymentScript,
}) {
  final senderOutpoints = {
    for (final input in original.inputs) (input.txid, input.vout),
  };
  final proposalOutpoints = [
    for (final input in proposal.inputs) (input.txid, input.vout),
  ];
  final proposalOutpointSet = proposalOutpoints.toSet();
  if (senderOutpoints.isEmpty ||
      senderOutpoints.length != original.inputs.length ||
      proposalOutpointSet.length != proposalOutpoints.length ||
      !proposalOutpointSet.containsAll(senderOutpoints)) {
    return null;
  }

  final inputOwners = proposalOutpoints
      .map(
        (outpoint) => senderOutpoints.contains(outpoint)
            ? PayjoinParty.sender
            : PayjoinParty.recipient,
      )
      .toList();
  if (!inputOwners.contains(PayjoinParty.sender) ||
      !inputOwners.contains(PayjoinParty.recipient)) {
    return null;
  }

  final paymentOutputs = original.outputs
      .where((output) => _sameScript(output.scriptPubkey, paymentScript))
      .toList();
  if (paymentOutputs.length != 1 || proposal.outputs.isEmpty) return null;

  final senderOutputIndexes = <int>{};
  for (final output in original.outputs) {
    if (_sameScript(output.scriptPubkey, paymentScript)) continue;
    final matches = [
      for (final (index, candidate) in proposal.outputs.indexed)
        if (_sameScript(output.scriptPubkey, candidate.scriptPubkey)) index,
    ];
    if (matches.length != 1 || !senderOutputIndexes.add(matches.single)) {
      return null;
    }
  }

  final outputOwners = [
    for (final (index, _) in proposal.outputs.indexed)
      senderOutputIndexes.contains(index)
          ? PayjoinParty.sender
          : PayjoinParty.recipient,
  ];
  return PayjoinOwnership(inputs: inputOwners, outputs: outputOwners);
}

Uint8List? paymentScriptFromBip21(String bip21, {required bool isTestnet}) {
  try {
    final address = Uri.parse(bip21).path;
    if (address.isEmpty) return null;
    return bdk.Address(
      address: address,
      network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    ).scriptPubkey().toBytes();
  } catch (_) {
    return null;
  }
}

bool _sameScript(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
