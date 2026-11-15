import 'dart:typed_data';

import 'package:bull_payjoin/src/domain/payjoin_ports.dart';
import 'package:bull_payjoin/src/domain/payjoin_session.dart';
import 'package:primitives/primitives.dart';

/// The network a session's addresses belong to; sessions only record whether they are on test.
BitcoinNetwork sessionNetwork({required bool isTestnet}) =>
    isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;

/// Sum of the outputs of [transaction] paying [address]; zero when [address] does not decode.
int amountReceived(
  PayjoinTransaction transaction, {
  required PayjoinCodecPort codec,
  required String address,
  required bool isTestnet,
}) {
  final script = codec.addressScript(
    address,
    sessionNetwork(isTestnet: isTestnet),
  );
  if (script == null) return 0;
  var total = 0;
  for (final output in transaction.outputs) {
    if (_sameScript(output.scriptPubkey, script)) {
      total += output.value.value.toInt();
    }
  }
  return total;
}

PayjoinOwnership? derivePayjoinOwnership({
  required PayjoinTransaction original,
  required PayjoinTransaction proposal,
  required Uint8List paymentScript,
}) {
  final senderOutpoints = original.inputs.toSet();
  final proposalOutpoints = proposal.inputs;
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

Uint8List? paymentScriptFromBip21(
  String bip21, {
  required PayjoinCodecPort codec,
  required bool isTestnet,
}) {
  final String address;
  try {
    address = Uri.parse(bip21).path;
  } on FormatException {
    return null;
  }
  if (address.isEmpty) return null;
  return codec.addressScript(address, sessionNetwork(isTestnet: isTestnet));
}

bool _sameScript(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
