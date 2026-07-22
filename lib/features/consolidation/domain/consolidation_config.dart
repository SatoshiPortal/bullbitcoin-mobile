import 'dart:math';

/// Per-boot randomized parameters for Liquid consolidation.
///
/// A fixed trigger/batch size is fingerprintable — an observer could infer a
/// Bull wallet if consolidations always fire at the same UTXO count or split
/// into perfectly uniform batches. Randomizing per app launch (and passing the
/// values into lwk `consolidate`) breaks that signature cheaply.
///
/// `maximumInputs` is only ever jittered *downward* from the ~256 hard limit,
/// never up, so a batch can never exceed what a single confidential tx allows.
class ConsolidationConfig {
  ConsolidationConfig._();

  static final Random _rng = Random.secure();

  /// UTXO count above which `consolidate` produces PSETs. Uniform in 100–150.
  static final int highUtxoThreshold = 100 + _rng.nextInt(51);

  /// Max inputs per consolidation transaction. Uniform in 230–250 (never above
  /// the 250 safety cap).
  static final int maximumInputs = 230 + _rng.nextInt(21);

  /// Amount (in sats) of the decoy output added to each consolidation batch
  /// alongside the real drained output, so the transaction looks like an
  /// ordinary 2-output payment rather than an obvious many-in/one-out
  /// self-transfer. Liquid's confidential amounts mean this value is never
  /// visible on-chain to anyone but the wallet itself.
  static const int decoySats = 1;
}
