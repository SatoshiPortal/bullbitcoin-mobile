import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/frameworks/framework_errors.dart';
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:flutter/foundation.dart';
import 'package:trezor_connect/trezor_connect.dart';

/// Thin wrapper around the upstream `trezor_connect` package.
///
/// Responsibilities:
///   * Hold the shared `TrezorConnect` singleton.
///   * Translate Bull Bitcoin's parameter shapes into the package's request
///     types (the PSBT -> TrezorTxInput/TrezorTxOutput adapter lives in
///     `signPsbt` below).
///   * Expose the underlying `TrezorConnect` reference to the deeplink
///     listener (see lib/features/trezor/ui/trezor_deeplink_listener.dart),
///     which calls `connect.handleCallback(uri)` on every inbound URI that
///     matches the callback scheme.
///
/// Errors thrown here are raw package errors; the repository implementation
/// maps them to `TrezorApplicationError` at the layer boundary
class TrezorConnectDatasource {
  final TrezorConnect _connect;

  TrezorConnectDatasource({required TrezorConnect connect})
    : _connect = connect;

  /// Exposed so `TrezorDeeplinkListener` can call `handleCallback` on the
  /// same instance the package uses internally for `_callbacks` map lookup.
  TrezorConnect get connect => _connect;

  Future<List<TrezorAddressPublicKey>> getPublicKeyBundle(
    List<String> paths, {
    required bool isTestnet,
  }) async {
    final coin = trezorCoinLabelFor(isTestnet: isTestnet);
    final params = paths
        .map((path) => TrezorGetPublicKeyParams(path: path, coin: coin))
        .toList();

    final result = await _connect.getPublicKeyBundle(params);

    if (result == null) {
      throw Exception('Empty response from Trezor Suite');
    }

    return result;
  }

  /// Asks Trezor Suite to display the address for `derivationPath` on the
  /// device. Trezor derives the address locally from its own master seed
  /// and renders it for the user to compare against the in-app QR.
  ///
  /// Two-layer verification:
  ///   1. We pass `address:` so Trezor's firmware refuses the request if the
  ///      address it derives doesn't match our expected one.
  ///   2. We compare the returned `result.address` against `address` before
  ///      returning success
  ///
  /// Returns `true` only when both Trezor confirms on device AND the returned
  /// address equals the expected one.
  Future<bool> verifyAddress({
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    // Trezor Suite's deeplinking path parser rejects the `h` notation that
    // BDK / satoshifier emit in `wallet.derivationPath` (e.g.
    // `m/84h/0h/0h/0/0`) with `Failure_DataError`. The canonical Trezor
    // hardened-component marker is `'` — the same notation that our
    // already-working `getPublicKeyBundle` call uses (`m/84'/0'/0'`).
    // Normalize before sending.
    final normalizedPath = derivationPath.replaceAll('h', "'");

    final result = await _connect.getAddress(
      normalizedPath,
      address: address,
      showOnTrezor: true,
      coin: trezorCoinLabelFor(isTestnet: isTestnet),
      scriptType: inputScriptTypeFor(scriptType),
    );

    if (result == null) {
      throw Exception('No address returned from Trezor Suite');
    }
    if (result.address != address) {
      throw TrezorAddressMismatchException(
        expected: address,
        returned: result.address,
      );
    }
    return true;
  }

  /// Signs a base64-encoded PSBT via Trezor Connect.
  ///
  /// Pipeline:
  ///   1. Decode the PSBT with bdk_dart.
  ///   2. For each input: pull amount from witnessUtxo (always present for
  ///      segwit inputs per BIP-174); pull derivation path from
  ///      bip32Derivation; build a TrezorTxInput.
  ///   3. For each output: detect change vs external from bip32Derivation
  ///      presence; for change, use addressPath; for external, derive
  ///      address from scriptPubkey via bdk_dart.
  ///   4. Hand inputs/outputs to `connect.signTransaction(coin: ..., ...)`
  ///      where the coin label is selected via `trezorCoinLabelFor`.
  ///   5. Return Trezor's signed transaction (broadcast-ready hex in
  ///      `serializedTx`).
  ///
  /// Assumes BIP84 (P2WPKH segwit) inputs and outputs throughout — that's
  /// the only script type Bull Bitcoin wallets use today. The output script
  /// detector falls through gracefully for P2SH / P2PKH / P2TR via the
  /// detected `scriptType`. Inputs are hardcoded `SPENDWITNESS`; non-segwit
  /// support would extend `_detectInputScriptType` below.
  Future<TrezorSignedTransaction> signPsbt({
    required String psbtBase64,
    required bool isTestnet,
    required ScriptType scriptType,
  }) async {
    final psbt = bdk.Psbt(psbtBase64: psbtBase64);
    final psbtInputs = psbt.input();
    final psbtOutputs = psbt.output();

    final tx = psbt.extractTx();
    final txInputs = tx.input();
    final txOutputs = tx.output();

    if (psbtInputs.length != txInputs.length ||
        psbtOutputs.length != txOutputs.length) {
      throw Exception(
        'PSBT input/output count mismatch with extracted tx '
        '(psbt: ${psbtInputs.length} in / ${psbtOutputs.length} out; '
        'tx: ${txInputs.length} in / ${txOutputs.length} out)',
      );
    }

    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
    final inputScriptType = inputScriptTypeFor(scriptType);

    final inputs = <TrezorTxInput>[];
    for (var i = 0; i < psbtInputs.length; i++) {
      final psbtIn = psbtInputs[i];
      final txIn = txInputs[i];

      // Amount: prefer witnessUtxo (always present for segwit per BIP-174).
      // Fall back to nonWitnessUtxo's vout for legacy inputs (out of scope
      // for current BIP84-only wallets but kept defensive).
      int? amount;
      final wu = psbtIn.witnessUtxo;
      if (wu != null) {
        amount = wu.value.toSat();
      } else {
        final nwu = psbtIn.nonWitnessUtxo;
        if (nwu != null) {
          final prevOut = nwu.output()[txIn.previousOutput.vout];
          amount = prevOut.value.toSat();
        }
      }
      if (amount == null) {
        throw Exception(
          'PSBT input $i has neither witnessUtxo nor nonWitnessUtxo; '
          'cannot determine amount',
        );
      }

      // bip32Derivation is a Map<pubkey-hex, KeySource>. There can be one
      // entry per signer; for single-sig wallets there is exactly one.
      if (psbtIn.bip32Derivation.isEmpty) {
        throw Exception(
          'PSBT input $i has no bip32Derivation; Trezor cannot determine '
          'the signing key.',
        );
      }
      final keySource = psbtIn.bip32Derivation.values.first;
      final addressPath = keySource.path.toU32Vec();

      inputs.add(
        TrezorTxInput(
          // bdk's Txid.toString() returns the standard (big-endian display)
          // form, which is exactly the format Trezor's "previous transaction
          // hash (reversed)" expects on the wire.
          prevHash: txIn.previousOutput.txid.toString(),
          prevIndex: txIn.previousOutput.vout,
          amount: amount,
          addressPath: addressPath,
          sequence: txIn.sequence,
          scriptType: inputScriptType,
        ),
      );
    }

    final outputs = <TrezorTxOutput>[];
    for (var i = 0; i < psbtOutputs.length; i++) {
      final psbtOut = psbtOutputs[i];
      final txOut = txOutputs[i];

      final amount = txOut.value.toSat();

      if (psbtOut.bip32Derivation.isNotEmpty) {
        // Change output: pass derivation path so Trezor can re-derive
        // on-device. Use the wallet's ScriptType — P2SH-P2WPKH change
        // looks like plain P2SH at the script-pubkey level but Trezor
        // needs PAYTOP2SHWITNESS to validate the wrap correctly.
        final keySource = psbtOut.bip32Derivation.values.first;
        outputs.add(
          TrezorTxOutput(
            amount: amount,
            addressPath: keySource.path.toU32Vec(),
            scriptType: changeOutputScriptTypeFor(scriptType),
          ),
        );
      } else {
        // External destination: derive the address from scriptPubkey
        // and byte-detect the script type — we don't know what kind of
        // wallet the recipient uses, so we infer from the on-chain shape.
        final address = bdk.Address.fromScript(
          script: txOut.scriptPubkey,
          network: network,
        );
        outputs.add(
          TrezorTxOutput(
            amount: amount,
            address: address.toString(),
            scriptType: detectOutputScriptType(txOut.scriptPubkey.toBytes()),
          ),
        );
      }
    }

    final signed = await _connect.signTransaction(
      coin: trezorCoinLabelFor(isTestnet: isTestnet),
      inputs: inputs,
      outputs: outputs,
    );
    if (signed == null) {
      throw Exception('Empty signTransaction response from Trezor Suite');
    }
    return signed;
  }
}

/// Maps Bull Bitcoin's ScriptType to Trezor's `InputScriptType` label
/// for SIGNING (the `SPEND*` family). Reused by `signPsbt` for each
/// TrezorTxInput and by `verifyAddress` for the `getAddress` request.
@visibleForTesting
String inputScriptTypeFor(ScriptType scriptType) => switch (scriptType) {
  ScriptType.bip84 => 'SPENDWITNESS',
  ScriptType.bip49 => 'SPENDP2SHWITNESS',
  ScriptType.bip44 => 'SPENDADDRESS',
};

/// Maps wallet ScriptType to Trezor's output-script-type label for
/// CHANGE outputs (where the wallet's derivation family is known).
/// External outputs use [detectOutputScriptType] (byte detection) — we
/// can't know the recipient's wallet type from on-chain script alone.
@visibleForTesting
String changeOutputScriptTypeFor(ScriptType scriptType) => switch (scriptType) {
  ScriptType.bip84 => 'PAYTOWITNESS',
  ScriptType.bip49 => 'PAYTOP2SHWITNESS',
  ScriptType.bip44 => 'PAYTOADDRESS',
};

/// Detects Trezor's output script-type label from raw scriptPubkey bytes.
/// Used for EXTERNAL outputs only — wallet-owned change outputs use
/// [changeOutputScriptTypeFor] which knows the wallet's ScriptType.
///
/// P2SH-P2WPKH is indistinguishable from plain P2SH at the byte level,
/// so external P2SH outputs always get PAYTOSCRIPTHASH here.
@visibleForTesting
String detectOutputScriptType(List<int> bytes) {
  if (bytes.length == 22 && bytes[0] == 0x00 && bytes[1] == 0x14) {
    return 'PAYTOWITNESS'; // P2WPKH (BIP84)
  }
  if (bytes.length == 34 && bytes[0] == 0x00 && bytes[1] == 0x20) {
    return 'PAYTOWITNESS'; // P2WSH
  }
  if (bytes.length == 25 &&
      bytes[0] == 0x76 &&
      bytes[1] == 0xa9 &&
      bytes[2] == 0x14) {
    return 'PAYTOADDRESS'; // P2PKH
  }
  if (bytes.length == 23 &&
      bytes[0] == 0xa9 &&
      bytes[1] == 0x14 &&
      bytes[22] == 0x87) {
    return 'PAYTOSCRIPTHASH'; // P2SH
  }
  if (bytes.length == 34 && bytes[0] == 0x51 && bytes[1] == 0x20) {
    return 'PAYTOTAPROOT'; // P2TR
  }
  return 'PAYTOWITNESS'; // default for first-pass BIP84 wallets
}

@visibleForTesting
String trezorCoinLabelFor({required bool isTestnet}) =>
    isTestnet ? 'test' : 'btc';
