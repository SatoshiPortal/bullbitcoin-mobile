/// Recoverable failures this package surfaces to callers, as a sealed family
/// so a consumer can exhaustively handle them (BULL maps these to its own
/// feature `Failure`). These are values, not thrown `Error`s: an unsupported
/// address is user input, not a programmer bug.
sealed class ProofError implements Exception {
  final String message;
  const ProofError(this.message);

  @override
  String toString() => 'ProofError: $message';
}

/// The challenge address (or a proof UTXO's script) is not P2WPKH/P2TR — the
/// only types BIP-322 Simple/PoF supports here.
class UnsupportedScriptError extends ProofError {
  const UnsupportedScriptError(super.message);
}

/// A private key could not be resolved for one of the inputs, or it does not
/// match the script it is meant to sign.
class KeyResolutionError extends ProofError {
  const KeyResolutionError(super.message);
}

/// The proof string was malformed (bad prefix, base64, or PSBT). Verification
/// maps this to [ProofStatus.invalid] rather than throwing; proving never
/// produces it.
class MalformedProofError extends ProofError {
  const MalformedProofError(super.message);
}
