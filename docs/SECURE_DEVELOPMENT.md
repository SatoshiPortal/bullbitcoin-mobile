# Secure Development

Bull Bitcoin Mobile is a self-custodial Bitcoin + Liquid + Lightning wallet: the app holds the user's keys, and there is no custodian to fall back on.
A leak of key material is not a bug report, it is a loss of funds.
This document collects the threat model and the secure-development rules that already apply to this codebase, so contributors and reviewers share one reference instead of re-deriving it per pull request.

See [SECURITY.md](../SECURITY.md) for how to report a vulnerability; do not open a public issue for a security report.
See [AGENTS.md](../AGENTS.md) ("Security" section) for the condensed version of these rules aimed at AI coding agents; this document is the fuller, human-facing version.
See [ARCHITECTURE.md](../ARCHITECTURE.md) for the layer model referenced throughout ("domain boundary", "sealed UI", "facade").

## Scope

This document covers application-level secure development practices for the Flutter/Dart mobile app in this repository: key handling, screen/accessibility exposure, input validation, and dependency hygiene.
It does not cover server-side infrastructure, exchange backend security, or the security properties of the underlying protocols (Bitcoin, Liquid, Lightning, Boltz swaps, payjoin) themselves — those are out of scope here and tracked, where relevant, in their own repositories.

## Threat model (baseline)

This is a baseline for a self-custodial mobile wallet, not an exhaustive audit or a formal STRIDE/DREAD assessment.
It focuses on the loss-of-funds and privacy risks that are realistic given this app's architecture, and is meant to be extended as new features and attack surfaces are added.

- **Key material exposure.** Mnemonics, seeds, xprivs, PINs, and derived secrets must never reach logs, crash reporting (Sentry), analytics, or backups outside the user-controlled recovery flow.
  A single log line or exception message containing a seed is a full compromise, not a minor leak.
- **Screen and accessibility capture.** Screenshots, screen recording, and the OS accessibility/semantics tree are all avenues for a secret shown on screen (mnemonic, PIN) to leak to another app or a malicious accessibility service.
- **Long-lived in-memory secrets.** Caching key material in a singleton, a BLoC, or any object with a lifetime longer than the operation that needs it increases the window during which a memory dump, debugger attach, or crash report can expose it.
- **Deep links and inter-app input.** Payment URIs, PSBTs, LNURLs, and other externally-supplied data reach the app through deep links, QR scans, and clipboard paste.
  Unvalidated input at these entry points can corrupt domain state, address the wrong recipient, or forge a displayed amount.
- **Dependency supply chain.** BDK, LWK, Boltz, payjoin, and other native or pinned-git dependencies execute with the same privileges as the app.
  A compromised, unpinned, or unreviewed dependency update is equivalent to a compromised app.
- **Backup and recovery.** The recovery phrase is the single artifact that fully reconstructs a wallet's spending authority.
  Its display, storage, and any cloud-backup integration are the highest-value targets in the app and deserve the most scrutiny in review.
- **Local device compromise.** A rooted/jailbroken device, a malicious keyboard, or a malicious accessibility service already running on the device sit outside what an app-layer mitigation can fully prevent; the goal here is to raise the cost of casual or automated harvesting, not to defend against a fully compromised device.

## Network privacy model (by design)

The app does not try to hide the user's IP address from every server it talks to.
Tor protects a small, explicit set of traffic; hiding the IP for everything else is the job of a device-wide VPN such as Orbot in VPN mode, as the Tor settings screen tells the user.
This scope was narrowed on purpose in August 2026 (#2719), and tests pin it (`test/core_test/electrum/electrum_servers_adapter_test.dart`, "keeps Bitcoin clearnet direct with an enabled external proxy").

| Traffic | Route |
|---|---|
| RecoverBull key server | Tor: embedded, or the user's local SOCKS5 proxy (Orbot's SOCKS port) |
| Custom Bitcoin Electrum `.onion` server | Tor: embedded or local SOCKS5 proxy |
| Custom mempool `.onion` server, when it is validated | Embedded Tor only, even with the local SOCKS5 proxy configured |
| Bitcoin Electrum clearnet servers, default or custom | Direct, even with the local SOCKS5 proxy configured |
| Liquid Electrum | Direct; a Liquid `.onion` server is skipped, never contacted |
| RecoverBull vault on Google Drive | Direct |
| Payjoin | Direct to third-party OHTTP relays; the payjoin directory only sees the relay |
| Lightning address and LNURL resolution | Direct, to the recipient's domain |
| Silent Payments backend (BlindBit and its Electrum server) | Direct |
| Fee estimation, exchange API, websocket and webviews, Boltz and the swap API, prices, Sentry (consent-gated) | Direct |

The per-network `ElectrumSettings.socks5` column still takes precedence in the Electrum adapter, but no UI writes it any more, so it is empty in practice.

What reviewers and audit agents should not report as a vulnerability:

- A server seeing the user's IP address, or clearnet traffic not going through the SOCKS proxy, for traffic listed as direct above.
- DNS queries or IP exposure that a device-wide VPN would hide.

What still is a finding:

- Traffic the table or the UI says goes through Tor that actually goes direct.
- An `.onion` hostname resolved outside Tor on a path that claims a Tor route; the Electrum socket connector refuses this on purpose.
- A custom server silently replaced by a Bull default; custom servers never fall back (see `ElectrumServersPort`).
- Identifiers of the user's own servers (URLs, hosts) written to the shareable log or sent to Sentry.

Known open findings: the Electrum and mempool server storage datasources still log server URLs at FINE, which reaches the shareable log; a `.onion` host happens to be redacted, a clearnet one is not.

Known limitation, not a design choice: fee estimation fetches a custom mempool server directly, so a `.onion` mempool server fails to return fees unless a device-wide VPN routes `.onion` traffic, and under such a VPN embedded Tor may not bootstrap, so the server cannot be validated either; in practice a `.onion` mempool server is not usable for fee estimation today.

## Secure development rules (applicable today)

These rules are already enforced by code review and the architecture rules in [AGENTS.md](../AGENTS.md), not by a dedicated security gate — see "Current enforcement status" below for what that means in practice.

- **Never log secrets.** Mnemonics, seeds, xprivs, PINs, and raw key material never reach logs, Sentry, or analytics.
  Scrub before reporting; assume anything logged is exfiltrated.
- **Secrets are ephemeral.** Read from `flutter_secure_storage` at the point of use; don't cache key material in long-lived BLoC or singleton state.
  Treat a revealed value as short-lived and re-read it rather than holding a reference.
- **Sealed UI for display.** Show a secret through a widget that reads it internally and never returns it (the `MnemonicView` pattern — see [ARCHITECTURE.md](../ARCHITECTURE.md) "Sealed UI as a security tool").
  Never add a getter that hands the raw value to a caller, even for "just logging" or "just testing".
- **Block capture on secret screens.** Use `no_screenshot` (or the equivalent platform API) plus exclusion from the semantics/accessibility tree on any screen that displays a secret.
- **Validate at the domain boundary.** Addresses, amounts, and descriptors are value objects that reject invalid input at construction — never trust a raw string deeper in the call chain.
  This is the same rule as AGENTS.md rule #9 (rich domain models), applied specifically to security-relevant primitives.
- **Flag key-material changes in the PR.** When a change touches key material, signing, or backup/recovery, say so explicitly in the PR description so it gets the right review attention.
- **Pin and review dependencies.** Cross-repo packages are pinned via `git: { url, ref }`, never `path:` deps (see AGENTS.md "Dependencies").
  A dependency bump that touches signing, key derivation, or network code deserves the same scrutiny as first-party code in that area.

## Where these rules live in the code

Pointers, not an exhaustive map — grep for the pattern if a reference below has moved:

- Secure storage access: `flutter_secure_storage` usages under `lib/core/` and the `secrets`/`recoverbull` domains.
- Sealed display widgets: `MnemonicView` and similar widgets that read a secret internally and never expose a getter for it.
- Screen-capture blocking: `no_screenshot` usage on mnemonic-display and PIN-entry screens.
- Domain-boundary validation: value objects such as `Amount`, `Address`, and descriptor types that validate in their constructor/factory (see AGENTS.md rule #9 and rule #6).
- Pinned dependencies: the `workspace:`-adjacent `dependencies:` block in the root `pubspec.yaml`, using `git: { url, ref }` for every cross-repo package.

## Advisory framework

[OWASP MASVS](https://mas.owasp.org/MASVS/) (Mobile Application Security Verification Standard) and [OWASP MASWE](https://mas.owasp.org/MASWE/) (Mobile Application Security Weakness Enumeration) are used here as an **advisory reference**, not as a certification target.
They provide a shared vocabulary and a checklist to sanity-check new features — for example MASVS-STORAGE for secret storage, or MASVS-PLATFORM for screen, clipboard, and IPC exposure.
Nothing in this repository claims MASVS compliance, and the app has not been formally assessed against MASVS or MASWE end to end.
Treat a MASVS/MASWE control ID cited in a PR or issue as a useful reference point for discussion, not as evidence that the corresponding requirement has been verified.

## Current enforcement status

**These rules are applied today through code review and the conventions in this document and in AGENTS.md — there is no automated security gate in CI.**
Concretely, as of this writing:

- There is no static analysis rule, lint, or CI job that detects a logged secret, a missing `no_screenshot` flag, or a raw-value getter on a sealed UI widget.
  Catching a violation depends entirely on a human reviewer applying the rules above.
- There is no dependency-vulnerability scanning (SCA) job wired into CI for this repository.
- There is no dedicated penetration test, fuzz target, or MASVS-mapped test suite in this codebase.
- Automating parts of this — an analyzer-plugin rule for secret-shaped log calls, a CI dependency-audit step, a MASVS-mapped checklist in the PR template — is a plausible future improvement, but it is **not currently implemented, scheduled, or resourced**.

Do not describe any of the above as "enforced by CI" or "gated" in a PR, issue, or review comment until it is actually wired in, and this document is updated to match.
Treat this section as the honest current baseline: security here is a matter of convention and review discipline, not tooling, until stated otherwise.
