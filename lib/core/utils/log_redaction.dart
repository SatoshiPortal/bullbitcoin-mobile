import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Privacy-safe tokens for log lines.
///
/// Log output leaves the device: the TSV log file is user-shareable for
/// support, SEVERE/SHOUT records reach Sentry, and console output routinely
/// gets pasted into issues. Anything that identifies on-chain activity —
/// addresses, txids, BIP21 URIs, outpoints, amounts, or wallet ids embedding
/// a master fingerprint — must therefore never be logged raw. Log an opaque
/// token instead, so lines still correlate for debugging without letting a
/// log reader look anything up on-chain.
///
/// Two tiers, chosen by the entropy of the value being protected:
///
/// * **Low-entropy identifiers** (txids, addresses, wallet ids, outpoints):
///   these exist in public datasets (the blockchain) or small search spaces
///   (a 32-bit master fingerprint), so an *unsalted* hash could be reversed
///   by hashing every candidate. Use [logSafeToken], which is salted with a
///   per-process random value: tokens correlate within one app run's logs
///   and are worthless outside it.
/// * **High-entropy identifiers** (a payjoin BIP21 URI carrying `pj`/`rk`
///   params): infeasible to brute-force, so a plain hash is safe and buys
///   stability across app restarts — important for correlating a resumed
///   payjoin session's logs with its pre-restart ones. See
///   `Payjoin.logRef` / `PayjoinModel.logRef`.
///
/// Amounts have no meaningful token form — a redacted amount carries no
/// debugging value — so they are simply not logged.

/// Random per-process salt. Deliberately NOT persisted: a salt that survives
/// restarts would let a leaked salt + logs be replayed against the public
/// chain, and cross-run correlation is not worth that risk for the
/// low-entropy tier.
final String _processSalt = () {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}();

/// A short (8 hex chars) salted token for a low-entropy identifier such as a
/// txid, an address, an outpoint or a wallet id. Stable within a single app
/// run (so log lines correlate), unrecoverable outside it (per-process
/// random salt — see the library doc above).
String logSafeToken(String? value) {
  if (value == null || value.isEmpty) return '<none>';
  return sha256
      .convert(utf8.encode('$_processSalt:$value'))
      .toString()
      .substring(0, 8);
}
