/// Classifies a Bitcoin Electrum broadcast rejection as transient (worth
/// retrying on the next server) or permanent (rethrown immediately, since no
/// other server can turn an invalid/rejected transaction into a valid one).
///
/// Pass this as `isTransient` to [ElectrumServersPort.runWithFallback] /
/// [runElectrumFallback] wherever a broadcast is attempted
/// (`broadcastTransaction` / `broadcastPsbt`), so a definitive mempool/policy
/// rejection from the first server — a double-spend, a non-final
/// transaction, a below-dust output, etc. — is never masked by silently
/// retrying the same rejected transaction against a second server. It stays
/// deliberately narrow: anything that doesn't match a known permanent
/// rejection falls back to the loop's own default (`e is Exception`), so
/// unrelated transient failures (timeouts, connection errors, protocol
/// hiccups) still advance to the next server exactly as before.
///
/// Matching is case-insensitive substring matching against `error.toString()`
/// — Electrum servers return these as plain-text mempool-accept reject
/// reasons (Bitcoin Core `policy.cpp` / `validation.cpp` strings), not
/// structured errors, so string matching is the only signal available at
/// this boundary.
///
/// The permanent phrases recognised:
/// - `missingorspent` / `missing or spent`: an input is already spent
///   (double-spend) or doesn't exist.
/// - `non-final` / `non-BIP68-final`: the transaction's timelock or
///   relative-locktime sequence isn't satisfied yet.
/// - `txn-mempool-conflict`: conflicts with another mempool transaction.
/// - `already in block chain`: the transaction is already confirmed.
/// - `bad-txns` (matches the `bad-txns-*` family): a structurally invalid
///   transaction.
/// - `mandatory-script-verify-flag` / `non-mandatory-script-verify-flag`:
///   script or signature validation failed.
/// - `dust`: an output is below the dust threshold.
///
/// These are intrinsic to the transaction itself, so trying another server
/// can never turn them into an accept. Deliberately *not* on this list:
/// `insufficient fee` / `min relay fee not met` — a server's relay/policy fee
/// floor is a per-server, often per-node-config setting, not a property of
/// the transaction, so a fee that one server's mempool rejects can still be
/// accepted by the next one. Treating those as permanent would abandon the
/// fallback loop on a rejection that a different server might not raise.
///
/// None of the phrases above can be fixed by trying a different server — the
/// transaction itself is the problem — so [isTransientBroadcastError] returns
/// `false` for all of them, which makes [runElectrumFallback] rethrow
/// immediately instead of masking the rejection as "all servers failed".
bool isTransientBroadcastError(Object error) {
  if (_isPermanentBroadcastRejection(error)) return false;
  return error is Exception;
}

const _permanentBroadcastRejectionPhrases = <String>[
  'missingorspent',
  'missing or spent',
  'non-final',
  'non-bip68-final',
  'txn-mempool-conflict',
  'already in block chain',
  'bad-txns',
  'mandatory-script-verify-flag',
  'non-mandatory-script-verify-flag',
  'dust',
];

bool _isPermanentBroadcastRejection(Object error) {
  final message = error.toString().toLowerCase();
  return _permanentBroadcastRejectionPhrases.any(message.contains);
}
