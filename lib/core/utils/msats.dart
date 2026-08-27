/// Converts a BOLT11 millisatoshi amount to satoshis, rounding up.
///
/// The conversion is lossy by construction: BOLT11 denominates in msats and
/// the pico-BTC multiplier makes sub-satoshi amounts expressible. Rounding up
/// rather than truncating keeps two properties the callers rely on — a
/// non-zero invoice never reads as zero, which would look like an amountless
/// invoice, and the satoshi view never understates what is owed, which is what
/// wallet selection compares against a balance.
///
/// A negative amount is clamped to zero: it cannot come from a valid invoice,
/// and returning it would propagate a negative balance into the send flow.
///
/// The same rule lives in `satoshifier`'s `Utils.msatsToSats`. The duplication
/// exists because this file's caller re-implements bolt11 parsing instead of
/// using `Bolt11Parser`; the two should converge when that is unified.
int msatsToSats(int msats) {
  if (msats <= 0) return 0;
  return (msats + 999) ~/ 1000;
}
