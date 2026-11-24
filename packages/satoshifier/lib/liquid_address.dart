/// Whether a Liquid address is confidential (carries a blinding public key,
/// so amounts paid to it are hidden by Confidential Transactions).
///
/// Sending to an unconfidential address makes the amount publicly visible
/// on-chain — the send flow warns before building such a payment.
///
/// The lwk bindings only report the network of an address, so the check is
/// structural:
/// - blech32(m) confidential addresses carry their own HRPs (`lq1` mainnet,
///   `tlq1` testnet);
/// - bech32 unconfidential addresses use `ex1` / `tex1`;
/// - Base58Check addresses have no HRP, but a confidential one embeds a
///   33-byte blinding key on top of the 25-byte payload, making it roughly
///   twice as long (~76 chars vs ~35) — length, not the version byte, is the
///   reliable signal across networks.
bool isConfidentialLiquidAddress(String address) {
  final lower = address.toLowerCase();
  if (lower.startsWith('lq1') || lower.startsWith('tlq1')) return true;
  if (lower.startsWith('ex1') || lower.startsWith('tex1')) return false;
  return address.length > 60;
}
