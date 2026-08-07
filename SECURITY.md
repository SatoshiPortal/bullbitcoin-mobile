# Security Policy

## Reporting a Vulnerability

Please report security vulnerabilities privately to **security@bullbitcoin.com**.

Do not open a public issue for security reports.

Include as much detail as possible (affected version, steps to reproduce, impact). We will acknowledge your report and keep you updated on the fix.

## Payjoin (BIP-77 / BIP-78) Security Notes

The wallet implements asynchronous payjoin via the `bull_payjoin` package, following [BIP-77](https://github.com/bitcoin/bips/blob/master/bip-0077.md) ("Async Payjoin") and [BIP-78](https://github.com/bitcoin/bips/blob/master/bip-0078.mediawiki). Protocol mechanics are delegated to the official Dart bindings [`payjoin` 0.2.1+payjoin-1.0.0-rc.8](https://pub.dev/packages/payjoin/versions/0.2.1+payjoin-1.0.0-rc.8) (verified publisher payjoin.org, UniFFI), which wrap the Payjoin Dev Kit — [rust-payjoin `payjoin-1.0.0-rc.8`](https://github.com/payjoin/rust-payjoin/releases/tag/payjoin-1.0.0-rc.8). The following behaviors are intentional protocol design — please do not report them as vulnerabilities:

- **The receiver holds a fully signed "original" (fallback) transaction from session start.** BIP-77 requires the Original PSBT to be "fully signed" and "broadcastable" ([§ Sender Original PSBT Messaging](https://github.com/bitcoin/bips/blob/master/bip-0077.md#sender-original-psbt-messaging)), and states that "at any point, either party may choose to broadcast the fallback transaction described by the Original PSBT" and that "there is no way for a sender to prevent a receiver from broadcasting the fallback transaction […] before the receiver-specified expiration time" ([§ Session Expiration](https://github.com/bitcoin/bips/blob/master/bip-0077.md#session-expiration)). This is the BIP-78 anti-probing mechanism, not a key leak.
- **One payjoin URI yields at most one proposal.** Sessions are single-request/single-response: a mailbox holds a single message and, once the receiver posts its proposal, "they wait for either transaction […] to be broadcast to the Bitcoin network" and stop polling ([§ Receiver Proposal PSBT Messaging](https://github.com/bitcoin/bips/blob/master/bip-0077.md#receiver-proposal-psbt-messaging)); session keys "are ephemeral and must only be used for a single Payjoin Session" ([§ Rationale — Secp256k1 HPKE](https://github.com/bitcoin/bips/blob/master/bip-0077.md#secp256k1-hybrid-public-key-encryption)); and the directory mailbox expires at the URI's `EX` timestamp ([§ Receiver fragment parameters](https://github.com/bitcoin/bips/blob/master/bip-0077.md#receiver-fragment-parameters)). A second original PSBT posted to the same URI is never processed.
- **The original and the proposal PSBT spend the same sender inputs**, so "they are mutually exclusive and only one can be confirmed" ([§ Overview](https://github.com/bitcoin/bips/blob/master/bip-0077.md#overview)); the Proposal PSBT must "include all inputs from the Original PSBT" ([§ Receiver Proposal PSBT Messaging](https://github.com/bitcoin/bips/blob/master/bip-0077.md#receiver-proposal-psbt-messaging)).

### Retries and double-payment considerations

A sender-side retry after an expired session is **not conflict-bound**: coin selection may pick inputs disjoint from the expired session's original, so the two originals do not double-spend each other (see the design comments in [`packages/bull_payjoin/lib/src/engine/payjoin_engine.dart`](packages/bull_payjoin/lib/src/engine/payjoin_engine.dart), `createPayjoinSender` and the sender-expiry fallback). In practice the exposure is minimal: a retry is only allowed after the sender session expires (default 24 h, [`packages/bull_payjoin/lib/src/domain/payjoin_policy.dart`](packages/bull_payjoin/lib/src/domain/payjoin_policy.dart)), by which time the receiver's mailbox has always expired too — the retried original never reaches the receiver.

The residual risk lives at the UX/social layer: if a receiver **re-issues a fresh payjoin URI for the same invoice** while still holding an unbroadcast original from a previous attempt, two non-conflicting signed originals can exist and both could confirm. Before re-issuing a payjoin URI, settle or invalidate any unresolved previous session.

Reports about novel payjoin double-spend paths remain welcome; please indicate whether the scenario reuses the same URI or involves a re-issued URI.
