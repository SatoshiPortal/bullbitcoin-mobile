# RecoverBull

The package owns backup creation, recovery, verification, provider selection and the connection screen. The host wires its public capabilities through `RecoverBullFeature`; host navigation, persistence and notifications stay behind injected ports.

## Tor connection policy

Opening a flow does not probe the key server until the connection screen requests it. A connection request performs one health check, with a deadline derived from `torConnectBudget` plus ten percent headroom (currently 66 seconds). Fetch and store retain their separate operation deadline. Connection failure details remain visible while a retry is running.

Retry reuses the flow's current route. New route is available after a failed embedded-Tor check and acquires a separate isolated session; it does not restart the shared Tor client. An external proxy is managed by the user, so the screen offers no new-route operation for it. Concurrent requests during session acquisition are ignored, and stale acquisition results cannot replace the current route.

The flow retains a verified route through benign directory refreshes. Fetch and store borrow it through `RecoverBullRoutePort`; retirement waits until the last borrower finishes. Provider selection or provider-save retries do not keep a network operation open. Terminal Tor loss retires the route, and the next requested attempt obtains and verifies a replacement. Leaving the flow retires its route without closing another feature's session.

## Secrets and diagnostics

Submission copies are discarded after handoff. Invalid credentials return to the same editable form; its input is cleared when the flow succeeds or a key is revealed, and on disposal. A cancelled acceptance workflow performs no new key request or reveal. No credential, decrypted mnemonic or revealed key belongs in a diagnostic callback.

Connection logs record bounded milestones and typed failure causes. Optional timing callbacks cannot change operation results, including after a successful server write. Native Tor support-log capture is composed by the host; its privacy and volume policy is documented in `packages/bull_tor/README.md`.

## Verification

Run the repository's `make checks` to verify all workspace members. Package tests cover connection policy and races, route ownership, cancellation, invalid-credential navigation, input cleanup and provider handling. Device plugin checks and live Tor circuit probes are separate measurements; they do not establish that a complete wallet recovery succeeds.
