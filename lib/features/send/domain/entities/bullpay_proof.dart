/// Transient wire input for the LUD-22 proof-of-funds callback (Approach B —
/// factor reconstruction). It is never persisted and carries no long-lived
/// secret: the UTXO signing key is zeroized immediately after the signature is
/// produced, and the value/asset blinding factors open only this single output
/// by construction (single-output disclosure, see the security notes in the
/// PR24 dossier §8.4).
///
/// The recipient's server reconstructs the on-chain Pedersen value commitment
/// and asset generator from [valueSat]/[valueBfHex] and [assetIdHex]/
/// [assetBfHex], compares them to the confidential outpoint on chain, then
/// enforces `asset == L-BTC` and `value >= floor`. No blinding key is sent, so
/// the recipient cannot unblind any other output of the payer's wallet.
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

  /// SLIP-77 value blinding factor (hex) for the output.
  final String valueBfHex;

  /// Unblinded asset id (hex) of the output.
  final String assetIdHex;

  /// SLIP-77 asset blinding factor (hex) for the output.
  final String assetBfHex;

  const BullpayProof({
    required this.outpoint,
    required this.pubkeyHex,
    required this.sigDerHex,
    required this.valueSat,
    required this.valueBfHex,
    required this.assetIdHex,
    required this.assetBfHex,
  });
}
