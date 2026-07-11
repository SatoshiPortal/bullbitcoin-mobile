import 'dart:typed_data';

import 'package:bip322/bip322.dart' as bip322;
import 'package:hex/hex.dart';

import 'errors.dart';
import 'models.dart';
import 'ports.dart';

/// BIP-322 "Proof of Funds": prove and verify control of a set of Bitcoin
/// UTXOs. This is a thin, pure-Dart adapter over the `bip322` package — all
/// wallet/chain access is injected via [PrivateKeyResolver] and [ChainLookup],
/// so this package has no dependency on BDK, Electrum, or Flutter.
class ProofOfFunds {
  const ProofOfFunds();

  /// Builds a `pof`-prefixed BIP-322 Proof of Funds signature for [message],
  /// with [challengeAddress] as the message challenge (input 0) and every
  /// entry in [utxos] proven as an additional input.
  ///
  /// [keys] resolves each input's private key from its scriptPubKey. Throws
  /// [UnsupportedScriptError] if the challenge address or any UTXO script is
  /// not P2WPKH/P2TR, and [KeyResolutionError] if a key can't be resolved or
  /// doesn't match its script.
  Future<String> prove({
    required String message,
    required String challengeAddress,
    required List<ProofInput> utxos,
    required PrivateKeyResolver keys,
    required ProofNetwork network,
  }) async {
    final net = _network(network);

    // Reject an out-of-scope challenge address up front, translating the
    // bip322 library's thrown Error into our own recoverable failure value
    // (an unsupported address is user input, not a programmer bug).
    final bip322.ParsedAddress parsed;
    try {
      parsed = bip322.parseAddress(challengeAddress, net);
    } on bip322.Bip322Exception catch (e) {
      throw UnsupportedScriptError('invalid challenge address: $e');
    }
    _assertSupportedType(parsed.type);

    final Uint8List challengeKey;
    try {
      challengeKey = await keys.keyForScript(
        Uint8List.fromList(parsed.scriptPubKey.bytes),
      );
    } catch (e) {
      throw KeyResolutionError('challenge key: $e');
    }

    final proofUtxos = <bip322.ProofOfFundsUtxo>[];
    for (final u in utxos) {
      if (bip322.classifyScriptPubKey(bip322.Script(u.scriptPubKey)) == null) {
        throw UnsupportedScriptError(
          'proof UTXO ${u.outpoint} has an unsupported scriptPubKey type',
        );
      }
      final Uint8List key;
      try {
        key = await keys.keyForScript(u.scriptPubKey);
      } catch (e) {
        throw KeyResolutionError('key for ${u.outpoint}: $e');
      }
      proofUtxos.add(
        bip322.ProofOfFundsUtxo(
          prevout: _outpoint(u.outpoint),
          amount: u.amountSat.toInt(),
          scriptPubKey: bip322.Script(u.scriptPubKey),
          privateKey: key,
        ),
      );
    }

    try {
      return bip322.Bip322.signProofOfFunds(
        message: message,
        address: challengeAddress,
        privateKey: challengeKey,
        proofUtxos: proofUtxos,
        network: net,
      );
    } on bip322.InvalidPrivateKeyException catch (e) {
      throw KeyResolutionError('key does not match its script: $e');
    }
  }

  /// Verifies a `pof` [signature] over [message] for [challengeAddress].
  ///
  /// Runs the offline cryptographic check, then — when [chain] is supplied —
  /// compares each proven input's CLAIMED output (the scriptPubKey + amount its
  /// signature actually committed to, exposed by `bip322.ProvenUtxo`) against
  /// the real on-chain output, also checking it is unspent. This on-chain
  /// comparison is essential: the offline check alone attests only that the
  /// prover signed over the data it supplied, not that that data matches the
  /// real UTXO, so a proof could otherwise claim an outpoint it does not
  /// control.
  ///
  /// Never throws for malformed signature data — that resolves to
  /// [ProofStatus.invalid]. Throws [UnsupportedScriptError] for an
  /// out-of-scope challenge address.
  Future<ProofResult> verify({
    required String signature,
    required ProofNetwork network,
    ChainLookup? chain,
  }) async {
    final net = _network(network);

    // Self-contained per BIP-322 v2: the message (0x09 global field) and the
    // challenge scriptPubKey (input 0) are recovered from the proof itself.
    final result = bip322.Bip322.verifyProofOfFundsFromSignature(signature);

    final status = switch (result.status) {
      bip322.ProofOfFundsStatus.valid => ProofStatus.valid,
      bip322.ProofOfFundsStatus.inconclusive => ProofStatus.inconclusive,
      bip322.ProofOfFundsStatus.invalid => ProofStatus.invalid,
    };

    final challengeAddress = result.challengeScriptPubKey == null
        ? null
        : _addressFromScript(result.challengeScriptPubKey!, net);

    // Offline-only path: report cryptographically proven outpoints, unchecked.
    if (chain == null || status == ProofStatus.invalid) {
      return ProofResult(
        status: status,
        proven: [
          for (final u in result.provenUtxos)
            ProvenUtxo(
              outpoint: _fromOutpoint(u.outPoint),
              onChain: OnChainStatus.notChecked,
            ),
        ],
        lockTime: result.lockTime,
        sequence: result.sequence,
        message: result.message,
        challengeAddress: challengeAddress,
      );
    }

    // On-chain path: each proven input now carries the (scriptPubKey, amount)
    // its signature actually committed to (bip322.ProvenUtxo). Compare that
    // claimed output against the live UTXO set — no PSBT re-decode needed.
    final proven = <ProvenUtxo>[];
    var downgraded = false;
    for (final u in result.provenUtxos) {
      final outpoint = _fromOutpoint(u.outPoint);
      final onchain = await chain.lookup(outpoint);
      final OnChainStatus s;
      if (onchain == null) {
        s = OnChainStatus.mismatchOrMissing;
      } else if (!_bytesEqual(onchain.scriptPubKey, u.scriptPubKey) ||
          onchain.amountSat != BigInt.from(u.amount)) {
        s = OnChainStatus.mismatchOrMissing;
      } else if (!onchain.unspent) {
        s = OnChainStatus.spent;
      } else {
        s = OnChainStatus.confirmedUnspent;
      }
      if (s != OnChainStatus.confirmedUnspent) downgraded = true;
      proven.add(ProvenUtxo(outpoint: outpoint, onChain: s));
    }

    return ProofResult(
      // A proof that is cryptographically valid but fails the on-chain check
      // (spent, missing, or a claimed-vs-real mismatch) is not trustworthy.
      status: downgraded ? ProofStatus.invalid : status,
      proven: proven,
      lockTime: result.lockTime,
      sequence: result.sequence,
      message: result.message,
      challengeAddress: challengeAddress,
    );
  }

  /// Re-encodes a challenge [scriptPubKey] (P2WPKH/P2TR) as an address string
  /// for display. Returns `null` for any other script type — purely cosmetic,
  /// so a failure never affects the verify result.
  String? _addressFromScript(Uint8List scriptPubKey, bip322.Network net) {
    return bip322.Bip322.addressFromScriptPubKey(scriptPubKey, network: net);
  }

  bip322.Network _network(ProofNetwork n) => switch (n) {
    ProofNetwork.mainnet => bip322.Network.mainnet,
    ProofNetwork.testnet => bip322.Network.testnet,
    ProofNetwork.signet => bip322.Network.signet,
    ProofNetwork.regtest => bip322.Network.regtest,
  };

  /// Converts a display (big-endian) txid hex + vout into the internal
  /// (little-endian) byte order BIP-322's [bip322.OutPoint] expects.
  bip322.OutPoint _outpoint(ProofOutpoint op) {
    final le = Uint8List.fromList(HEX.decode(op.txId).reversed.toList());
    return bip322.OutPoint(le, op.vout);
  }

  ProofOutpoint _fromOutpoint(bip322.OutPoint op) {
    final be = HEX.encode(op.hash.reversed.toList());
    return ProofOutpoint(txId: be, vout: op.index);
  }

  void _assertSupportedType(bip322.AddressType type) {
    switch (type) {
      case bip322.AddressType.p2wpkh:
      case bip322.AddressType.p2tr:
        return;
      case bip322.AddressType.p2pkh:
      case bip322.AddressType.p2sh:
      case bip322.AddressType.p2wsh:
        throw UnsupportedScriptError(
          'challenge address type $type is not supported (P2WPKH/P2TR only)',
        );
    }
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
