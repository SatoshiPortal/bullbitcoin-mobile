import 'dart:typed_data';

/// The Bitcoin network a proof is built/verified for. Mirrors BIP-322's
/// address prefixes; kept as a local enum so consumers do not depend on the
/// `bip322` package's own `Network` type.
enum ProofNetwork { mainnet, testnet, signet, regtest }

/// A transaction outpoint (`txid:vout`). [txId] is the display (big-endian)
/// hex form, exactly as a wallet UTXO listing exposes it — the adapter is
/// responsible for converting to the internal byte order BIP-322 needs.
class ProofOutpoint {
  final String txId;
  final int vout;

  const ProofOutpoint({required this.txId, required this.vout});

  @override
  bool operator ==(Object other) =>
      other is ProofOutpoint && other.txId == txId && other.vout == vout;

  @override
  int get hashCode => Object.hash(txId, vout);

  @override
  String toString() => '$txId:$vout';
}

/// One UTXO whose control is being proven: the on-chain output ([amountSat],
/// [scriptPubKey]) at [outpoint]. The signer must be able to satisfy it — the
/// [PrivateKeyResolver] maps its [scriptPubKey] to the key that can sign.
///
/// Only P2WPKH and P2TR outputs are supported by the underlying BIP-322
/// implementation; anything else surfaces as a [ProofError.unsupportedScript].
class ProofInput {
  final ProofOutpoint outpoint;
  final BigInt amountSat;
  final Uint8List scriptPubKey;

  const ProofInput({
    required this.outpoint,
    required this.amountSat,
    required this.scriptPubKey,
  });
}

/// The three-state outcome BIP-322 defines for verifying a proof.
///
/// - [valid]: the challenge signature and every proof input verified
///   cryptographically (and, when a chain lookup was provided, every proven
///   UTXO matched the on-chain output and was unspent).
/// - [inconclusive]: at least one proof input used a script this library does
///   not understand (not P2WPKH/P2TR), or the `to_sign` version is unknown —
///   per the spec, never silently accepted.
/// - [invalid]: a structural or cryptographic check failed, or (when a chain
///   lookup was provided) a proven UTXO did not match on-chain or was spent.
enum ProofStatus { valid, inconclusive, invalid }

/// The on-chain state of a single proven UTXO, populated only when a
/// [ChainLookup] was supplied to verification.
enum OnChainStatus {
  /// Not checked (no [ChainLookup] provided).
  notChecked,

  /// The claimed output matches the on-chain output and is unspent.
  confirmedUnspent,

  /// The output exists and matches but is already spent.
  spent,

  /// The output does not exist on-chain, or its scriptPubKey/amount does not
  /// match what the proof claimed — a forged or stale claim.
  mismatchOrMissing,
}

/// One proven UTXO in a verification result: cryptographically proven offline,
/// with an optional [onChain] state from the live UTXO-set lookup.
class ProvenUtxo {
  final ProofOutpoint outpoint;
  final OnChainStatus onChain;

  const ProvenUtxo({required this.outpoint, required this.onChain});
}

/// The result of verifying a proof: the overall [status] plus the list of
/// [proven] UTXOs (with per-UTXO on-chain state when checked).
///
/// A purely offline check ([ChainLookup] not supplied) can only attest to the
/// cryptographic validity of the inputs, not that the UTXOs exist or are
/// unspent — per BIP-322, a validator needs the current UTXO set for that.
class ProofResult {
  final ProofStatus status;
  final List<ProvenUtxo> proven;

  /// nLockTime of `to_sign` — "T" in the spec's "valid at time T and age S".
  final int lockTime;

  /// nSequence of `to_sign`'s first input — "S" in the same phrase.
  final int sequence;

  /// The message the proof commits to, recovered from the proof itself
  /// (BIP-322 0x09 field). `null` if the proof did not embed it.
  final String? message;

  /// The challenge address the proof is signed for, recovered from the proof
  /// (input 0's scriptPubKey). `null` if it could not be recovered/encoded.
  final String? challengeAddress;

  const ProofResult({
    required this.status,
    required this.proven,
    this.lockTime = 0,
    this.sequence = 0,
    this.message,
    this.challengeAddress,
  });

  bool get isValid => status == ProofStatus.valid;
}

/// The on-chain output data returned by a [ChainLookup].
class ChainUtxo {
  final Uint8List scriptPubKey;
  final BigInt amountSat;
  final bool unspent;

  const ChainUtxo({
    required this.scriptPubKey,
    required this.amountSat,
    required this.unspent,
  });
}
