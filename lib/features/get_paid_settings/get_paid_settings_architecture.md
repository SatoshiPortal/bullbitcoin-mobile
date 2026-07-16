# Get Paid Settings Architecture

`get_paid_settings` owns the user-facing activation and status controls for the
optional encrypted keychain-manifest backup used by deterministic Get Paid
wallets. It does not own key derivation, encryption, persistence, scheduling,
or Bullnym transport.

## Boundaries

- UI calls `GetPaidSettingsCubit` only.
- The cubit calls feature-local use cases.
- Feature-local use cases consume `keychain_manifest/public` and map its durable
  state into `GetPaidSettings`.
- Bullnym, key material, xprvs, ETags, and ciphertext never cross this feature's
  presentation boundary.

Enabling the toggle is the single explicit storage decision. There is no
separate disclosure acknowledgement or compatibility state. Disabling stops
future stores and preserves pending work. Remote deletion is a separate
confirmed action exposed only while automatic backup is disabled.

Manual backup failures remain visible to the cubit. Automatic post-commit,
startup, resume, and successful-sync retries remain owned by
`keychain_manifest` and never fail product-wallet creation.
