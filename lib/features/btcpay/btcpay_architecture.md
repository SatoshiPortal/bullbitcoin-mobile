# BTCPay

BTCPay owns the SamRock pairing surface exposed from Bitcoin Settings.

## Scope

- Entry point: Bitcoin Settings -> BTCPay.
- This feature pairs a BTCPay Server store with dedicated BTCPay Bitcoin and Liquid wallets.
- Both wallets use the registry-owned BTCPay reservation at BIP39 English 12-word path `39'/0'/12'/100'`. BTCPay obtains the typed wallet index through the registry facade and supplies product policy as a deterministic-wallet request; it does not own reservation or wallet materialization machinery.
- SamRock `btc-ln` is supported as Lightning via Liquid/Boltz descriptor setup. It does not expose the later Get Paid Lightning Address flow.
- BTCPay records one local Keychain Manifest reserved derivation with Bitcoin and Liquid wallet materializations after deterministic wallets are prepared and before payload construction or descriptor submission. If that local record step fails, descriptors are not shared and prepared wallets are kept for retry.
- BTCPay applies wallet-owned behavior defaults best-effort after server acceptance. BTCPay Liquid is hidden from Home and auto-sweep enabled by default; BTCPay Bitcoin is visible and auto-sweep disabled by default. Those settings remain editable from the BTCPay details screen.
- This feature does not expose Get Paid navigation, dashboard, automated recovery, Lightning Address, Payment Page, invoices, Nostr, Bullnym, manual BIP85 creation, or non-BTCPay wallet behavior settings.

## Boundaries

- Settings may navigate to BTCPay through `public/btcpay_routes.dart`.
- Settings must not import BTCPay domain, data, presentation, or UI internals.
- BTCPay pairing orchestration belongs in BTCPay use cases under `domain/usecases/`.
- BTCPay may consume `features/deterministic_wallets/public/` and must not import deterministic wallet internals.
- BTCPay may consume `features/bip85_registry/public/` and must not import registry internals or duplicate the reserved index.
- BTCPay may consume `features/keychain_manifest/public/` and must not import keychain manifest internals. Keychain Manifest stores local derivation metadata only; it never stores mnemonic words, seeds, private keys, or descriptors.
- BTCPay may consume wallet behavior use cases to apply and edit settings for its own wallets. The wallet layer owns those flags and their persistence; BTCPay does not own the auto-sweep runner.
- BTCPay UI consumes presentation state and view models. It must not import BTCPay domain entities directly. Typed failures are translated only by the presentation-owned localization extension.
- BTCPay UI and Cubits must not create wallets, derive BIP85 material, submit descriptors, or decide rollback behavior directly.
- BTCPay stores its pairing connection through `BtcpayConnectionRepository`, whose implementation persists a wire model via the existing secure key-value storage abstraction. Datasources are private members of their repository and are never reached from presentation or UI.

## Layers

- `domain/`: SamRock request parsing, BTCPay connection entity, BTCPay wallet policy constants, network mapping, the `BtcpayConnectionRepository` contract, the `SamRockPairingServicePort` capability port, the SamRock setup payload builder, and the sealed `BtcpayFailure` family.
- `domain/usecases/`: preview, connection fetch, and full SamRock pairing orchestration.
- `data/models/`: the `BtcpayConnectionModel` wire model owning JSON encode/decode.
- `data/mappers/`: strict model <-> entity mapping and semantic validation.
- `data/`: `BtcpayConnectionRepositoryImpl`, which owns its datasource and maps wire models to domain entities.
- `data/datasources/`: secure-storage connection datasource (returns wire models only) and HTTP SamRock datasource.
- `presentation/`: Cubit state, failure localization, loading/submitting/success states, and connection view models.
- `ui/screens/`: settings and scanner screens.
- `public/`: route exported to Settings.

## Pairing Contract

- Users must explicitly consent before descriptors are submitted to BTCPay.
- The consent copy always discloses both dedicated Bitcoin and Liquid wallets because the SamRock slice prepares both reserved wallets even when a server asks for only one payment rail.
- The proven BIP85 path and parent fingerprint returned by deterministic wallet preparation are persisted in the Keychain Manifest. BTCPay never reconstructs recovery metadata from a duplicated constant.
- Once wallets have been materialized, they and their manifest entries are kept for retry. Payload construction or manifest failures do not roll them back.
- Explicit SamRock rejection is not saved as a connection; transport/server/unknown completion failures are saved as `uncertain`. Both outcomes retain prepared wallets and recovery metadata.
- Wallet behavior default failures after server acceptance are logged and do not fail pairing because those settings can be retried independently.
- SamRock submits the requested setup in one HTTP call, so the feature persists a single `uncertain` state rather than pretending to have per-rail server ACKs.
- Pairing state is scoped by wallet environment and persists the BTCPay server URL, SamRock store ID, requested capabilities, paired wallet networks, status, update timestamp, and pairing timestamp when confirmed.
- Every recoverable boundary returns a typed `Result`; raw exceptions, pairing URL/OTP values, descriptors, response bodies, and server text never reach presentation. Logs contain only safe failure categories.
- A 2xx response with explicit `Success: false` is rejection. Missing or malformed success evidence, non-2xx responses, redirects, and transport failures are uncertain. Users are told to check the server before retrying.

## Deferred

- Neutral external receive wallet abstractions belong to a later PR only after another concrete consumer exists.
- Full deterministic Get Paid navigation and recovery are stacked on top of this feature in a later PR.
