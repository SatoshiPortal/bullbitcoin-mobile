# Feature Dependencies

This diagram shows the dependencies between features in the Bull Bitcoin Mobile application. It helps visualize the dependency graph and ensures there are no cyclic dependencies.

**Diagram Type**: This is a **Package Dependency Diagram** (also known as Module Dependency Graph or Component Dependency Diagram in UML).

## Module Dependency Graph

```mermaid
graph TB
    %% Core infrastructure
    CORE[Core<br/>---<br/>Database, Secure Storage,<br/>API Clients, Tor Adapters, UI Kit,<br/>PIN encrypted storage,<br/>Domain Primitives/Value Objects]
    PRIMITIVES[Primitives Package<br/>Shared values, results and network fees]
    BULL_UI[Bull UI Package<br/>Design system]
    BULL_LOGGER[Bull Logger Package<br/>Logger, diagnostics, log files]
    BULL_PAYJOIN[Bull Payjoin Package<br/>Public contract]
    WALLET[Wallet Package<br/>Wallet domain contracts, metadata catalog port and native ownership]
    TRANSACTION_SYNC[Transaction Sync Package<br/>Local-source-first snapshots, freshness, source coordination]
    NOTIFICATIONS[Notifications Package<br/>Durable outbox and deferred destinations]
    BACKGROUND_TASKS[Background Tasks Package<br/>Headless dispatch and wallet sync orchestration]
    BULL_SDK[Bull SDK External Dependency<br/>BDK/LWK native adapters]

    %% Feature modules
    SETTINGS[Settings]
    LOGS[Logs<br/>Workspace Feature]
    ELECTRUM_SETTINGS[Electrum Settings]
    TOR_SETTINGS[Tor Settings]
    RECOVERBULL[RecoverBull]
    TOR[Tor<br/>Workspace Package]
    PIN_CODE[Pin Code]
    LABELS[Labels]
    SECRETS[Secrets Package<br/>Custody: storage, derivation, signing, backup]
    HW_WALLETS[Hardware Wallets]
    BTC_PRICE[Bitcoin Price]
    NETWORK[Network]
    BIP85[BIP85]
    FEES[Fees]
    WALLETS[Wallets]
    EXCHANGE[Exchange]
    EXCHANGE_SETTINGS[Exchange Settings]
    EXCHANGE_SUPPORT_CHAT[Exchange Support Chat]
    APP_STARTUP[App Startup]
    UTXO_MGMT[UTXO Management]
    ADDRESS_MGMT[Address Management]
    RECIPIENTS[Recipients]
    FUNDING[Funding]
    BACKUPS[Backups]
    SWAPS[Swaps]
    WITHDRAWAL[Withdrawal]
    STATUS[Status]
    SEND[Send]
    RECEIVE[Receive]
    TRANSFER[Transfer]
    TX_HISTORY[Transaction History]
    REPLACE_BY_FEE[Replace By Fee]
    DCA[DCA]
    DEFAULT_WALLETS[Default Wallets]
    LIMIT_ORDERS[Limit Orders]
    SELL[Sell]
    PAY[Pay]
    BUY[Buy]
    COINS[Coins / UTXOs]
    ANNOUNCEMENTS[Announcements]
    CONSOLIDATION[Consolidation]
    ALL_SEED_VIEW[All Seed View]
    APP_UNLOCK[App Unlock]
    AUTOSWAP[Autoswap]
    SP[Silent Payments]
    AUTOBUY[AutoBuy]

    %% Dependencies to Core (all features depend on Core, but showing it explicitly would clutter the diagram)
    %% Instead, we note this in the documentation below

    %% Published use-cases extracted from core wallet
    IMPORT_MNEMONIC[Import Mnemonic]
    ONBOARDING[Onboarding]
    ALL_SEED_VIEW --> WALLETS
    AUTOSWAP --> ADDRESS_MGMT
    BUY --> WALLETS
    IMPORT_MNEMONIC --> WALLETS
    LIMIT_ORDERS --> ADDRESS_MGMT
    LIMIT_ORDERS --> WALLETS
    ONBOARDING --> WALLETS
    PAY --> ADDRESS_MGMT
    PAY --> SEND
    RECEIVE --> WALLETS
    SELL --> SEND
    SEND --> ADDRESS_MGMT
    STATUS --> WALLETS
    SWAPS --> ADDRESS_MGMT
    SWAPS --> SEND
    SWAPS --> WALLETS

    %% Extracted package dependencies
    CORE --> PRIMITIVES
    CORE --> BULL_LOGGER
    LOGS --> BULL_LOGGER
    LOGS --> PRIMITIVES
    LOGS --> BULL_UI
    SETTINGS --> LOGS
    CORE --> BULL_PAYJOIN
    BULL_PAYJOIN --> PRIMITIVES
    CORE --> WALLET
    CORE --> TRANSACTION_SYNC
    WALLET --> TRANSACTION_SYNC
    WALLET --> PRIMITIVES
    WALLET --> BULL_LOGGER
    WALLET --> BULL_SDK
    TRANSACTION_SYNC --> PRIMITIVES
    CORE --> NOTIFICATIONS
    CORE --> BACKGROUND_TASKS
    SETTINGS --> NOTIFICATIONS
    SETTINGS --> BACKGROUND_TASKS
    NOTIFICATIONS --> PRIMITIVES
    BACKGROUND_TASKS --> TRANSACTION_SYNC
    BACKGROUND_TASKS --> NOTIFICATIONS
    BACKGROUND_TASKS --> BULL_LOGGER
    BACKGROUND_TASKS --> PRIMITIVES

    %% Feature-to-feature dependencies (extracted from draw.io diagram)
    ADDRESS_MGMT --> LABELS
    ADDRESS_MGMT --> WALLET
    BUY --> ADDRESS_MGMT
    DCA --> ADDRESS_MGMT
    RECEIVE --> ADDRESS_MGMT
    SELL --> ADDRESS_MGMT
    ALL_SEED_VIEW --> APP_UNLOCK
    ALL_SEED_VIEW --> SECRETS
    ANNOUNCEMENTS --> SETTINGS
    ANNOUNCEMENTS --> SWAPS
    APP_STARTUP --> WALLETS
    APP_STARTUP --> SECRETS
    APP_STARTUP --> LOGS
    AUTOSWAP --> SWAPS
    APP_STARTUP --> TOR
    AUTOSWAP --> TRANSFER
    AUTOBUY --> DEFAULT_WALLETS
    BIP85 --> SECRETS
    BIP85 --> SETTINGS
    BACKUPS --> BIP85
    BACKUPS --> RECOVERBULL
    BACKUPS --> TOR
    BACKUPS --> WALLETS
    BTC_PRICE --> SETTINGS
    BUY --> EXCHANGE
    BUY --> RECEIVE
    BUY --> BULL_PAYJOIN
    BUY --> TX_HISTORY
    COINS --> UTXO_MGMT
    COINS --> LABELS
    COINS --> WALLET
    PAY --> COINS
    SELL --> COINS
    SEND --> COINS
    SWAPS --> COINS
    WALLETS --> COINS
    COINS --> WALLETS
    DCA --> RECEIVE
    SETTINGS --> DEFAULT_WALLETS
    SETTINGS --> EXCHANGE
    SETTINGS --> EXCHANGE_SETTINGS
    EXCHANGE_SETTINGS --> EXCHANGE
    EXCHANGE --> AUTOBUY
    LIMIT_ORDERS --> EXCHANGE
    EXCHANGE --> EXCHANGE_SUPPORT_CHAT
    EXCHANGE --> BTC_PRICE
    EXCHANGE --> DCA
    EXCHANGE --> FUNDING
    EXCHANGE --> TX_HISTORY
    EXCHANGE --> WITHDRAWAL
    SETTINGS --> EXCHANGE_SUPPORT_CHAT
    WALLETS --> EXCHANGE_SUPPORT_CHAT
    SWAPS --> EXCHANGE_SUPPORT_CHAT
    REPLACE_BY_FEE --> EXCHANGE_SUPPORT_CHAT
    DCA --> EXCHANGE
    PAY --> EXCHANGE
    TX_HISTORY --> EXCHANGE
    WALLETS --> EXCHANGE
    WITHDRAWAL --> EXCHANGE
    LIMIT_ORDERS --> DEFAULT_WALLETS
    LIMIT_ORDERS --> FUNDING
    FEES --> NETWORK
    FUNDING --> EXCHANGE
    FUNDING --> RECIPIENTS
    HW_WALLETS --> CORE
    LABELS --> CORE
    LABELS --> WALLET
    PAY --> RECIPIENTS
    PAY --> BULL_PAYJOIN
    PIN_CODE --> CORE
    RECEIVE --> BULL_PAYJOIN
    RECEIVE --> SETTINGS
    RECEIVE --> SWAPS
    RECEIVE --> TX_HISTORY
    RECIPIENTS --> EXCHANGE
    SELL --> EXCHANGE
    SELL --> RECIPIENTS
    SELL --> BULL_PAYJOIN
    SELL --> TX_HISTORY
    SEND --> CONSOLIDATION
    SEND --> FEES
    SEND --> NETWORK
    SEND --> BULL_PAYJOIN
    SEND --> SP
    SEND --> SWAPS
    SEND --> TX_HISTORY
    SEND --> UTXO_MGMT
    SEND --> WALLETS
    SETTINGS --> CORE
    SETTINGS --> BULL_PAYJOIN
    SETTINGS --> RECOVERBULL
    SETTINGS --> TOR_SETTINGS
    TOR_SETTINGS --> TOR
    STATUS --> BULL_PAYJOIN
    STATUS --> TOR
    SWAPS --> BULL_PAYJOIN
    SWAPS --> SECRETS
    SWAPS --> EXCHANGE
    SWAPS --> LABELS
    SWAPS --> TX_HISTORY
    SETTINGS --> SP
    WALLETS --> SP
    SWAPS --> UTXO_MGMT
    CORE --> TOR
    ELECTRUM_SETTINGS --> TOR
    WALLETS --> TOR
    WALLETS --> ELECTRUM_SETTINGS
    RECOVERBULL --> TOR
    RECOVERBULL --> SECRETS
    TRANSFER --> CONSOLIDATION
    TRANSFER --> SEND
    TRANSFER --> RECEIVE
    TX_HISTORY --> BULL_PAYJOIN
    TX_HISTORY --> SWAPS
    TX_HISTORY --> WALLET
    TX_HISTORY --> LABELS
    REPLACE_BY_FEE --> TX_HISTORY
    TX_HISTORY --> WALLETS
    UTXO_MGMT --> LABELS
    UTXO_MGMT --> WALLETS
    WALLETS --> BIP85
    WALLETS --> CONSOLIDATION
    WALLETS --> HW_WALLETS
    WALLETS --> NETWORK
    WALLETS --> SECRETS
    SP --> SECRETS
    WALLETS --> SETTINGS
    WALLETS --> SWAPS
    WITHDRAWAL --> RECIPIENTS

    %% Styling
    classDef coreStyle fill:#2d3748,stroke:#4a5568,stroke-width:3px,color:#fff
    classDef packageStyle fill:#234e52,stroke:#319795,stroke-width:2px,color:#e6fffa
    classDef featureStyle fill:#1a202c,stroke:#2d3748,stroke-width:2px,color:#e2e8f0

    class CORE coreStyle
    class SECRETS,WALLET,PRIMITIVES,BULL_UI,BULL_PAYJOIN,TRANSACTION_SYNC,NOTIFICATIONS,BACKGROUND_TASKS,BULL_SDK,TOR packageStyle
    class SETTINGS,PIN_CODE,LABELS,HW_WALLETS,BTC_PRICE,NETWORK,BIP85,FEES,WALLETS,EXCHANGE,EXCHANGE_SETTINGS,EXCHANGE_SUPPORT_CHAT,APP_STARTUP,UTXO_MGMT,ADDRESS_MGMT,RECIPIENTS,FUNDING,BACKUPS,SWAPS,WITHDRAWAL,STATUS,SEND,RECEIVE,TRANSFER,TX_HISTORY,REPLACE_BY_FEE,AUTOSWAP,AUTOBUY,DCA,DEFAULT_WALLETS,LIMIT_ORDERS,SELL,PAY,BUY,COINS,ANNOUNCEMENTS,CONSOLIDATION,ALL_SEED_VIEW,APP_UNLOCK,SP featureStyle
```

## About Package Dependency Diagrams

### What This Diagram Shows

- **Modules/Packages**: Each box represents a self-contained feature/package
- **Dependencies**: Arrows show "depends on" relationships (A → B means "A depends on B")
- **Direction**: Dependencies flow from dependent to dependency (not data flow)

### Standard Information in Package Diagrams

1. **Module Names**: Clear identification of each package/feature
2. **Dependency Direction**: Arrows indicating which module depends on which
3. **Optional Elements** (can be added):
   - Dependency type labels (e.g., "uses facade", "imports types")
   - Stereotypes like `<<core>>`, `<<feature>>`, `<<infrastructure>>`
   - Access modifiers (public/internal APIs)
   - Dependency cardinality (required vs optional)

## Dependency Rules

1. **No Cyclic Dependencies**: Features must not create circular dependency chains
2. **Core Independence**: Core must not depend on any feature
3. **Feature Isolation**: Features should communicate through well-defined facades/interfaces
4. **Layered Dependencies**: Dependencies flow one way — `shell → features → packages` across modules, and `ui → presentation → domain → data` within a feature. Under the melos migration each `lib/core/<domain>` becomes a `packages/<domain>` and these turn into compile-time boundaries. See [ARCHITECTURE.md](ARCHITECTURE.md).

## Core Dependencies

**Important**: All features implicitly depend on Core for foundational services. These dependencies are not shown in the diagram to reduce visual clutter.

### What Core Provides

1. **Infrastructure Services**:

   - Database (Drift/SQLite)
   - Secure Storage instance (Flutter Secure Storage)
   - API Clients (REST/GraphQL clients)
   - Embedded Onion adapter with isolated RecoverBull and Bitcoin Electrum `.onion` sessions
   - Explicit local SOCKS5 override for Bitcoin Electrum and encrypted backups
   - UI Kit (shared widgets, theme)
   - PIN encrypted storage

2. **Core Primitives**:
   - Canonical location: `packages/primitives`; compatibility exports remain in `lib/core` during migration.
   - Extracted examples: `Failure`, `Result`, `Fingerprint`, network types, `Outpoint`, `Sats`, and `FeeRate`. Security-domain types such as `Secret` now live in `packages/secrets`, which owns them rather than exposing them as primitives.
   - Shared types used across multiple features, avoiding redundant definitions
   - Immutable, validated value objects that ensure domain integrity

> Migration note: `lib/core` is shared infrastructure (no business logic). Shared *domain* modules that historically landed in `lib/core/<domain>` (e.g. `wallet`) graduate into `packages/<domain>` under the melos workspace — each exposing its repository interfaces + domain types + shared use-cases through a public API, never a bloc or screen. See [ARCHITECTURE.md](ARCHITECTURE.md).

## Key Dependency Patterns

### Central Features (Highly Depended Upon)

- **Core**: Foundation for all features
- **Tor**: `packages/bull_tor` — embedded Onion lifecycle with isolated RecoverBull and Bitcoin Electrum `.onion` sessions, plus provider-agnostic local SOCKS5 verification. Depends on Flutter for app-directory storage and an iOS plugin that excludes Tor state from backups, which are infrastructure-package exceptions in AGENTS.md
- **Transaction Sync**: `packages/transaction_sync` — local-source-first Bitcoin/Liquid synchronization contracts, immutable process snapshots, freshness/evidence, and the shared per-wallet SDK-state coordinator. Wallet and the host adapters consume the source coordinator; Background Tasks owns foreground scheduling while production transaction UI remains on the label-enriching transaction repository; see the migration status in [ARCHITECTURE.md](ARCHITECTURE.md)
- **Notifications**: `packages/notifications` — local-notification gateway, durable collision-safe outbox, silent topic baselines, and deferred post-unlock destinations
- **Background Tasks**: `packages/background_tasks` — foreground scheduling, headless task outcomes, payment observation, the activity channel and WorkManager adapter; composes Transaction Sync, Notifications, Bull Logger, and Primitives without importing app features
- **Address Management**: Wallet owns native address selection/revelation and balance/history projection. Address View publishes label-enriched WalletAddress values and supplies reservation/decoration callbacks under the same source gate.
- **Transaction History**: Owns the label-enriched `WalletTransaction`, `TransactionInput`, and `TransactionOutput` projections, published by `TransactionsFacade`. The same feature owns the label-enriching transaction repository, domain-detail mappers, transaction lookup and sync-stream projection use-cases. WalletTransactionReader publishes domain details from normalized snapshots for lists and targeted native reads for exact lookup; the feature adds labels. status localization stays in presentation.
- **Wallets**: Used by Send, UTXO Management, Transaction History, Backups, App Startup
- **Secrets** (workspace package): Used by Wallets, BIP85, App Startup, All Seed View, RecoverBull, Swaps, Silent Payments
- **Settings**: Used by Wallets, BIP85, Bitcoin Price
- **Recipients**: Used by Pay, Withdrawal
- **UTXO Management**: The wallet package owns label-free WalletCoin values, native UTXO reads, freeze state and coordination. The Coins public facade publishes the label-enriched WalletUtxo projection and its repository contract for Send, Sell, Pay, Swaps and Wallets. The Labels freeze adapter lives in the shell to avoid a Labels-to-Coins dependency cycle.

### Leaf Features (Depend on Many, Few Depend on Them)

- **Send**: Depends on Fees, Network, Payjoin, Swaps, UTXO Management, Wallets
- **Receive**: Depends on Payjoin, Swaps
- **Backups**: Depends on BIP85, Tor, Wallets

### Exchange-Related Features

- **Buy, Sell, Funding**: All depend on Exchange
- **Recipients**: Depends on Exchange

## Verification

To verify no cyclic dependencies exist, you can:

1. **Manual trace**: Follow any path through the graph - it should never return to a previously visited node
2. **Automated tools**: Use `dart pub deps` or custom dependency analysis scripts
3. **Import analysis**: Review import statements in facade/public API files

## Future Improvements

- Add dependency type labels (e.g., "uses facade", "imports primitives")
- Document which specific APIs each feature exposes
- Add dependency cardinality (required vs optional dependencies)
- Include compile-time vs runtime dependency distinction
- Add layer groupings (ui, presentation, domain, data) per [ARCHITECTURE.md](ARCHITECTURE.md)

## Shell composition during isolation

The root `lib/locator.dart` owns infrastructure and feature registration; `lib/wallet_setup.dart` supplies the wallet's host adapters. There is no CoreLocator or forwarding barrel under `lib/core`. Notification resource names and the unchanged outbox filename live in `lib/notification_adapters.dart`.

Background execution enters through `lib/background_entrypoint.dart`; `lib/background_bootstrap.dart` assembles the graph and `lib/sync_runtime_adapters.dart` supplies foreground jobs and background Electrum configuration. Scheduling, budgets, the activity channel and payment-observation policy live in Background Tasks. The current headless bootstrap still builds the application locator with foreground watchers disabled; reducing it to the required services remains part of the isolation work.

The workspace dependency graph is acyclic (verified with `fvm dart run melos list --cycles` on 2026-11-04). The legacy feature graph above includes existing cycles and does not claim otherwise. Normalized foreground history publication and removal of transitional wallet datasource/model exports remain pending.
