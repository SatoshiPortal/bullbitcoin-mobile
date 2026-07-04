/// Transient wire input for the LUD-22 proof-of-funds callback (Approach B —
/// factor reconstruction). It is never persisted and carries no long-lived
/// secret: the UTXO signing key is zeroized immediately after the signature is
/// produced, and the value/asset blinding factors open only this single output
/// by construction (single-output disclosure, see the security notes in the
/// PR24 dossier §8.4).
///
/// The recipient's server reconstructs the on-chain Pedersen value commitment
/// from [valueSat]/[valueBfHex] and rebinds the asset generator to its OWN
/// L-BTC id using [assetBfHex], comparing both to the confidential outpoint on
/// chain, then enforces `value >= floor`. The client sends NO asset id (the
/// server owns the asset binding) and NO blinding key (so the recipient cannot
/// unblind any other output of the payer's wallet).
class BullpayProof {
  /// `"{txId}:{vout}"` of the proof output.
  final String outpoint;

  /// Compressed P2WPKH public key (hex) controlling [outpoint].
  final String pubkeyHex;

  /// ECDSA-DER signature (hex) over
  /// `sha256("bullpay-lnurlp-v1" ++ nym ++ outpoint)`.
  final String sigDerHex;

  /// Unblinded value of the output, in satoshis.
  final BigInt valueSat;

  /// Value blinding factor for the output, as elements display-order hex —
  /// the verbatim `TxOutSecrets.valueBf` string from LWK. Never re-hexed from
  /// raw bytes (that would reverse the byte order and fail the server rebind).
  final String valueBfHex;

  /// Asset blinding factor for the output, as elements display-order hex —
  /// the verbatim `TxOutSecrets.assetBf` string from LWK.
  final String assetBfHex;

  const BullpayProof({
    required this.outpoint,
    required this.pubkeyHex,
    required this.sigDerHex,
    required this.valueSat,
    required this.valueBfHex,
    required this.assetBfHex,
  });
}
