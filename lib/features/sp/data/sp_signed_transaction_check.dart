import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/bwk.dart' as bwk;

/// Compares the transaction the account extracted from the signed PSBT with
/// the simulation the user confirmed, so the app does not take bwk's pin on
/// its word (packages/secrets/doc/design.md, § Silent payments).
///
/// bwk's `finalize` already refuses a signed PSBT that differs from its
/// simulation and verifies every silent payment output; this is defense in
/// depth against a bug in that code. The inputs must be exactly the simulated
/// outpoints; each output must be the simulated one at its index, by amount
/// always and by script for standard destinations (a silent payment script is
/// derived while signing, so only its taproot shape can be known in advance);
/// every recipient the user confirmed must be paid exactly once; the change
/// and the fee must be the simulated ones.
///
/// The change is then checked independently of the code that derived it:
/// bwk's receiving path, the one the scanner uses, must find exactly the
/// simulated change outputs in the transaction ([change]).
///
/// These checks catch a buggy signer or account, not a malicious one: the
/// signer and the receiving path are bwk's too.
abstract final class SpSignedTransactionCheck {
  /// Why [signed], a raw transaction, differs from [simulation], or null when
  /// it matches. The reason carries counts, indexes and amounts only, so it
  /// is safe to log.
  static String? mismatch({
    required Uint8List signed,
    required bwk.TxSimulation simulation,
    required bwk.SpNetwork network,
  }) {
    final bdk.Transaction tx;
    try {
      tx = bdk.Transaction(transactionBytes: signed);
    } catch (_) {
      return 'the signed bytes are not a transaction';
    }

    final spent = [
      for (final input in tx.input())
        '${input.previousOutput.txid}:${input.previousOutput.vout}'
            .toLowerCase(),
    ]..sort();
    final simulated = [
      for (final coin in simulation.inputs) coin.outpoint.toLowerCase(),
    ]..sort();
    if (!_sameList(spent, simulated)) {
      return 'inputs differ: ${spent.length} spent, '
          '${simulated.length} simulated';
    }

    final outputs = [
      for (final output in tx.output())
        (
          sat: BigInt.from(output.value.toSat()),
          script: _hex(output.scriptPubkey.toBytes()),
        ),
    ];
    if (outputs.length != simulation.txOutputs.length) {
      return 'output count differs: ${outputs.length} signed, '
          '${simulation.txOutputs.length} simulated';
    }

    // Each simulated output, at its index.
    final described = <int>{};
    for (final simulatedOutput in simulation.txOutputs) {
      final vout = simulatedOutput.vout;
      if (vout < 0 || vout >= outputs.length || !described.add(vout)) {
        return 'the simulation describes output $vout out of range or twice';
      }
      final output = outputs[vout];
      if (output.sat != simulatedOutput.amountSat) {
        return 'output $vout pays ${output.sat} sat, '
            '${simulatedOutput.amountSat} simulated';
      }
      switch (simulatedOutput.destination) {
        case bwk.OutputDestination_SilentPayment():
          if (!_isTaproot(output.script)) {
            return 'silent payment output $vout is not a taproot output';
          }
        case bwk.OutputDestination_Address(:final address):
          final script = _script(address, network);
          if (script == null) {
            return 'the address of output $vout does not parse';
          }
          if (script != output.script) {
            return 'output $vout pays another script than simulated';
          }
        case bwk.OutputDestination_Script(:final scriptHex):
          if (scriptHex.toLowerCase() != output.script) {
            return 'output $vout pays another script than simulated';
          }
      }
    }

    // The recipients the user confirmed: each paid exactly once, by an
    // output that is not change.
    final payees = [
      for (final o in simulation.txOutputs)
        if (!o.isChange) o,
    ];
    if (payees.length != simulation.outputs.length) {
      return 'recipient count differs: ${payees.length} paid, '
          '${simulation.outputs.length} confirmed';
    }
    for (final recipient in simulation.outputs) {
      final index = payees.indexWhere(
        (o) => _pays(o, recipient, outputs[o.vout].script, network),
      );
      if (index < 0) {
        return 'no output pays ${_amount(recipient)} sat to a confirmed '
            'recipient';
      }
      payees.removeAt(index);
    }

    final change = simulation.txOutputs
        .where((o) => o.isChange)
        .fold(BigInt.zero, (sum, o) => sum + o.amountSat);
    if (change != simulation.changeSat) {
      return 'change differs: $change sat in the outputs, '
          '${simulation.changeSat} simulated';
    }

    final inputTotal = simulation.inputs.fold(
      BigInt.zero,
      (sum, coin) => sum + coin.amountSat,
    );
    final outputTotal = outputs.fold(BigInt.zero, (sum, o) => sum + o.sat);
    final fee = inputTotal - outputTotal;
    if (fee != simulation.feeSat) {
      return 'fee differs: $fee paid, ${simulation.feeSat} simulated';
    }
    return null;
  }

  /// Why the outputs bwk's receiving path found in the transaction ([owned])
  /// disagree with the simulated change, or null when they agree: the owned
  /// outputs reported as change must be exactly the simulated change outputs,
  /// by index and amount. The reason carries counts and amounts only.
  static String? change({
    required List<bwk.SpOwnedOutput> owned,
    required bwk.TxSimulation simulation,
  }) {
    final found = [
      for (final output in owned)
        if (output.isChange) (vout: output.vout, sat: output.amountSat),
    ]..sort((a, b) => a.vout.compareTo(b.vout));
    final expected = [
      for (final output in simulation.txOutputs)
        if (output.isChange) (vout: output.vout, sat: output.amountSat),
    ]..sort((a, b) => a.vout.compareTo(b.vout));
    if (expected.isEmpty) {
      if (found.isEmpty) return null;
      return 'the receiving path found ${found.length} change outputs, '
          'none simulated';
    }
    if (found.isEmpty) {
      return 'change output not recognised by the receiving path';
    }
    if (!_sameList(found, expected)) {
      return 'the receiving path found ${found.length} change outputs '
          '(${[for (final f in found) f.sat]} sat), ${expected.length} '
          'simulated (${[for (final e in expected) e.sat]} sat)';
    }
    return null;
  }

  // Whether [output], paying [script], is the payment to [recipient]: a
  // standard recipient by its address's script, a silent payment recipient
  // by the address the simulation resolved; the amount in both cases.
  static bool _pays(
    bwk.SimulatedOutput output,
    bwk.RecipientView recipient,
    String script,
    bwk.SpNetwork network,
  ) => switch (recipient) {
    bwk.RecipientView_Standard(:final address, :final amountSat) =>
      output.amountSat == amountSat && _script(address, network) == script,
    bwk.RecipientView_Sp(:final address, :final amountSat) =>
      output.amountSat == amountSat &&
          switch (output.destination) {
            bwk.OutputDestination_SilentPayment(address: final paid) =>
              paid.toLowerCase() == address.toLowerCase(),
            _ => false,
          },
  };

  static BigInt _amount(bwk.RecipientView recipient) => switch (recipient) {
    bwk.RecipientView_Standard(:final amountSat) => amountSat,
    bwk.RecipientView_Sp(:final amountSat) => amountSat,
  };

  // The script [address] pays, or null when it does not parse for [network].
  static String? _script(String address, bwk.SpNetwork network) {
    try {
      return _hex(
        bdk.Address(
          address: address,
          network: _bdkNetwork(network),
        ).scriptPubkey().toBytes(),
      );
    } catch (_) {
      return null;
    }
  }

  // OP_1 followed by a 32-byte push: a segwit v1 output.
  static bool _isTaproot(String script) =>
      script.length == 68 && script.startsWith('5120');

  static bdk.Network _bdkNetwork(bwk.SpNetwork network) => switch (network) {
    bwk.SpNetwork.bitcoin => bdk.Network.bitcoin,
    bwk.SpNetwork.testnet => bdk.Network.testnet,
    bwk.SpNetwork.signet => bdk.Network.signet,
    bwk.SpNetwork.regtest => bdk.Network.regtest,
  };

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
