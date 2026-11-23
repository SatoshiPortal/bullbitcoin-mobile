# Feature Dependencies

This diagram shows the dependencies between features in the Bull Bitcoin Mobile application. It helps visualize the dependency graph, including known legacy cycles that remain to be removed.

**Diagram Type**: This is a **Package Dependency Diagram** (also known as Module Dependency Graph or Component Dependency Diagram in UML).

## Module Dependency Graph

```mermaid
graph TB
    %% Core infrastructure
    CORE[Core<br/>---<br/>API Clients, Tor Adapters,<br/>DI & Router setup,<br/>Domain Primitives/Value Objects]
    PRIMITIVES[Primitives Package<br/>Shared values, signer classification and payment networks]
    ARK[Ark]
    ARK_PROTOCOL[Ark Protocol Package]
    BULL_UI[Bull UI Package]
    APP_STARTUP -->|app theme| BULL_UI
    WALLETS --> ARK
    SETTINGS --> ARK
    SEND --> ARK
    ARK --> ARK_PROTOCOL
    ARK --> PRIMITIVES
    ARK --> SECRETS
    ARK --> BG_TASKS
    ARK --> NOTIFICATIONS
    ARK --> BULL_UI
    ARK --> BULL_PRICER
    ARK --> BULL_LOGGER
    ARK -->|funding and wallet display data| SYNC
    TX_HISTORY -->|Payjoin signing guard| ARK_PROTOCOL
    TX_HISTORY -->|Payjoin receiver fees| FEES_PACKAGE
    TX_HISTORY -->|Payjoin admission| LEGACY_STORAGE
    ARK_PROTOCOL --> PRIMITIVES
    BG_TASKS --> ARK_PROTOCOL
    WALLETS --> BULL_PRICER
    ELECTRUM[Electrum package<br/>Server selection, settings and transaction lookup]
    SYNC[Sync Package<br/>Native lifecycle, Electrum sync, BitcoinTx, review values, chain access,<br/>contracts and owner ports]
    NOTIFICATIONS[Notifications Package]
    LEGACY_STORAGE[Legacy Storage Package<br/>Historical app database, cutover marker,<br/>lifecycle admission and imports]
    CORE --> LEGACY_STORAGE
    WALLETS --> LEGACY_STORAGE
    BIP85 --> LEGACY_STORAGE
    LEGACY_STORAGE --> BULL_LOGGER
    LEGACY_STORAGE --> BULL_REPORTING
    BG_TASKS --> LEGACY_STORAGE
    MEMPOOL --> LEGACY_STORAGE
    MEMPOOL --> SECRETS
    ANNOUNCEMENTS --> LEGACY_STORAGE
    ANNOUNCEMENTS --> SECRETS
    LEGACY_STORAGE --> PRIMITIVES
    BG_TASKS --> SYNC
    BG_TASKS --> SECRETS
    BG_TASKS --> PREFERENCES
    BG_TASKS --> TOR
    BG_TASKS --> ELECTRUM
    BG_TASKS --> NOTIFICATIONS
    WALLETS --> NOTIFICATIONS
    WALLETS --> BG_TASKS
    NOTIFICATIONS --> PRIMITIVES
    BG_TASKS --> PRIMITIVES
    BG_TASKS --> BULL_LOGGER
    SETTINGS --> BG_TASKS
    SETTINGS --> NOTIFICATIONS
    WIZARD --> BG_TASKS
    WIZARD --> NOTIFICATIONS
    SYNC -->|authorized wallet descriptors| SECRETS
    SYNC --> PRIMITIVES
    SYNC --> BULL_LOGGER
    ELECTRUM --> SYNC
    ELECTRUM --> PRIMITIVES
    ELECTRUM --> BULL_LOGGER
    NETWORK --> ELECTRUM
    NETWORK --> MEMPOOL
    SEND_TOOLS --> ELECTRUM
    CORE --> ELECTRUM
    WALLETS --> ELECTRUM
    LABELS --> SYNC
    WALLETS --> SYNC
    FEES_UI --> BULL_UI
    FEES_UI --> FEES_PACKAGE
    SETTINGS -->|fee source navigation| FEES_UI
    NETWORK -->|Mempool status probe| FEES_PACKAGE
    FEES_PACKAGE --> PRIMITIVES
    CORE --> SYNC
    SEND --> SYNC
    SPEND[Spend Package<br/>Wallet-bound Bitcoin and Liquid preparation, signing and broadcast]
    SPEND --> SYNC
    SPEND --> SECRETS
    SPEND --> ARK_PROTOCOL
    SPEND --> FEES_PACKAGE
    SPEND --> PRIMITIVES
    SEND --> SPEND
    BULL_EXCHANGE -->|Sell and Pay review, sign and broadcast| SPEND
    TRANSFER --> SPEND
    FEES_PACKAGE -->|wallet connection policy| SYNC
    SEND_TOOLS --> SYNC
    SATOSHIFIER[Satoshifier Package]
    SEND_TOOLS -->|BBQR assembly| SATOSHIFIER
    SATOSHIFIER --> SYNC
    SATOSHIFIER --> BULL_LOGGER
    SEND -->|payment requests| SATOSHIFIER
    SWAPS -->|payment requests| SATOSHIFIER
    WALLETS -->|payment requests, public extended keys| SATOSHIFIER
    SEND_TOOLS --> SPEND
    SPEND -->|write-ahead Payjoin admission| BULL_PAYJOIN
    WALLETS --> LABELS
    BULL_REPORTING[Bull Reporting Package]
    BULL_REPORTING --> BULL_LOGGER
    CORE --> BULL_REPORTING
    SETTINGS --> BULL_REPORTING
    LABELS --> BULL_PAYJOIN
    TX_HISTORY --> LABELS
    TX_HISTORY --> SECRETS
    TX_HISTORY --> BULL_LOGGER
    APP_STARTUP --> BULL_LOGGER
    NETWORK --> BULL_LOGGER
    SCREEN_AWAKE[Screen Awake Package]
    WAKELOCK_PLUS[wakelock_plus Plugin]
    BULL_LOGGER[Bull Logger Package<br/>Logger, diagnostics, log files]
    BULL_PAYJOIN[Bull Payjoin Package<br/>Public contract]
    BULL_PRICER[Bull Pricer Package<br/>Bitcoin price and history]
    BBX_API[BBX API Package<br/>Exchange transport and wire models]
    EXCHANGE_DOMAIN[Exchange Package<br/>Account, orders, default payouts, KYC, stats and Confidential SEPA eligibility]
    BULL_EXCHANGE[Bull Exchange workspace feature<br/>Landing, authentication, dashboard, KYC, account and access settings, support chat, funding, withdrawals, recipient management, default payouts, AutoBuy, Buy, DCA, Sell and Pay]
    EXCHANGE --> BULL_EXCHANGE
    BULL_EXCHANGE -->|order details navigation and receipt labels| TX_HISTORY
    SETTINGS -->|mount account and access settings routes| BULL_EXCHANGE
    SUPPORT -->|support chat| BULL_EXCHANGE
    BULL_EXCHANGE --> BULL_UI
    BULL_EXCHANGE -->|dashboard price display| BTC_PRICE
    BULL_EXCHANGE -->|authorized payout and payin wallets| SECRETS
    BULL_EXCHANGE -->|receive issuance, fee-estimation addresses, and unspent coins| SYNC
    BULL_EXCHANGE -->|Buy receive and Sell and Pay send sessions| BULL_PAYJOIN
    BULL_EXCHANGE -->|quotes| BULL_PRICER
    BULL_EXCHANGE -->|spending wallet cards and home navigation| WALLETS
    BULL_EXCHANGE -->|address viewer supplied by the host| ADDRESS_LABELS
    BULL_EXCHANGE --> LABELS
    BULL_EXCHANGE -->|funding coin selection| COINS
    BULL_EXCHANGE --> FEES_UI
    BULL_EXCHANGE --> FEES_PACKAGE
    BULL_EXCHANGE --> PREFERENCES
    EXCHANGE --> EXCHANGE_DOMAIN
    WITHDRAW --> EXCHANGE_DOMAIN
    LIMIT_ORDERS --> EXCHANGE_DOMAIN
    SETTINGS --> EXCHANGE_DOMAIN
    TX_HISTORY --> EXCHANGE_DOMAIN
    EXCHANGE_DOMAIN --> PRIMITIVES
    EXCHANGE_DOMAIN -->|encrypted credential import| LEGACY_STORAGE
    EXCHANGE_DOMAIN -->|database key and legacy credential lifecycle| SECRETS
    EXCHANGE_DOMAIN -->|account, KYC, statistics, chat, notifications, funding, virtual IBANs, orders and default payouts| BBX_API
    BULL_EXCHANGE -->|support chat, account, statistics, funding, withdrawals, recipient management, default payouts and AutoBuy| EXCHANGE_DOMAIN
    EXCHANGE_DOMAIN -->|legacy environment selection| PREFERENCES

    SIGNERS[Signers<br/>Workspace Feature]
    SIGNERS --> PRIMITIVES
    SIGNERS --> SYNC
    SIGNERS --> BULL_UI

    %% Feature modules
    ARK[Ark Journeys<br/>Workspace Feature]
    ARK_NATIVE[Ark Package<br/>Native lifecycle and protocol operations]
    ARK --> ARK_NATIVE
    ARK --> SECRETS
    ARK --> SCANNING
    ARK --> PREFERENCES
    ARK --> PRIMITIVES
    ARK --> BULL_UI
    ARK --> BG_TASKS
    ARK --> NOTIFICATIONS
    ARK_NATIVE --> PRIMITIVES
    TRANSFER --> ARK
    SWAPS --> ARK
    TRANSFER -->|public receive address| WALLETS
    SEND --> ARK
    SETTINGS --> ARK
    QUICK_ACTIONS[Quick Actions<br/>Workspace Feature<br/>Catalogue and layout storage]
    WIZARD[Startup Wizard<br/>Workspace Feature]
    MNEMONIC_ENTRY[Mnemonic Entry]
    PHYSICAL_BACKUP_VERIFICATION[Physical Backup Verification]
    ONBOARDING[Onboarding]
    SETTINGS[Legacy Settings<br/>Preferences and child screens]
    SETTINGS_HUB[Settings home and search<br/>Workspace Feature]
    SETTINGS -->|menu projection and child routes| SETTINGS_HUB
    SETTINGS_HUB --> NETWORK
    SETTINGS_HUB --> BULL_UI
    SETTINGS_HUB --> PRIMITIVES
    PREFERENCES[Preferences Package]
    PREFERENCES --> LEGACY_STORAGE
    PREFERENCES --> SECRETS
    CORE -->|admitted owner and borrowed legacy| PREFERENCES
    NETWORK --> PREFERENCES
    SETTINGS --> PREFERENCES
    WALLETS --> PREFERENCES
    BTC_PRICE --> PREFERENCES
    COINS --> PREFERENCES
    COIN_SELECTION[Coins Workspace Feature<br/>Selection sheet]
    COIN_SELECTION --> BULL_UI
    COIN_SELECTION --> PRIMITIVES
    BULL_EXCHANGE --> COIN_SELECTION
    TRANSFER --> COIN_SELECTION
    EXCHANGE --> PREFERENCES
    SWAPS --> PREFERENCES
    SEND --> PREFERENCES
    PREFERENCES --> PRIMITIVES
    PREFERENCES --> TOR
    PREFERENCES --> BULL_REPORTING
    PREFERENCES --> BULL_LOGGER
    LOGS[Logs<br/>Workspace Feature]
    NETWORK[Network settings and service status<br/>Workspace Feature]
    RECOVERBULL[RecoverBull<br/>Workspace Feature]
    GOOGLE_DRIVE[Google Drive Package]
    RECOVERBULL --> GOOGLE_DRIVE
    FILE_SYSTEM[File System Package]
    RECOVERBULL --> FILE_SYSTEM
    BULL_EXCHANGE --> FILE_SYSTEM
    TX_HISTORY --> FILE_SYSTEM
    LABEL_EDITOR --> FILE_SYSTEM
    LABEL_EDITOR --> LABELS
    SEND --> LABEL_EDITOR
    RECEIVE --> LABEL_EDITOR
    TX_HISTORY --> LABEL_EDITOR
    TX_HISTORY --> BTC_PRICE
    SETTINGS --> LABEL_EDITOR
    TOR[Tor<br/>Workspace Package]
    ACCESS[Access<br/>Workspace Feature]
    ACCESS --> SECRETS
    ACCESS --> BULL_UI
    ACCESS --> PRIMITIVES
    ACCESS --> BULL_LOGGER
    LABELS[Labels Package<br/>Label persistence, BIP-329 and frozen UTXOs]
    LABEL_EDITOR[Label Editor<br/>Notes, labels and BIP-329 files]
    SECRETS[Secrets Package<br/>Custody: storage, derivation, signing, backup]
    HW_WALLETS[Hardware Wallets]
    BTC_PRICE[Bitcoin Price<br/>Workspace Feature]
    BIP85[BIP85<br/>Workspace Feature]
    FEES_PACKAGE[Fees Package]
    FEES_PACKAGE -->|receiver fee estimation port| BULL_PAYJOIN
    FEES_UI[Fees Feature]
    OVERVIEW[Wallet Overview workspace feature]
    WALLETS -->|balance cards and foreground refresh| OVERVIEW
    OVERVIEW --> BTC_PRICE
    OVERVIEW --> QUICK_ACTIONS
    OVERVIEW --> BULL_UI
    OVERVIEW --> SYNC
    OVERVIEW --> BULL_LOGGER
    WALLETS[Wallets]
    EXCHANGE[Exchange]
    SUPPORT[Support]
    APP_STARTUP[Startup workspace feature]
    UTXO_MGMT[UTXO Management]
    BACKUPS[Backups workspace feature<br/>Backup status and verification]
    SEND[Send]
    SEND_TOOLS[Send workspace feature<br/>Signed transaction broadcast, Liquid consolidation and fee replacement]
    SCANNING[QR and NFC Scanning workspace member]
    SEND_TOOLS -->|public QR and NFC scanning| SCANNING
    CORE -->|composes signer NFC callback| SCANNING
    SCANNING --> SIGNERS
    RECEIVE --> SIGNERS
    WALLETS --> SIGNERS
    WALLET_IMPORT[Wallet Import member]
    SETTINGS -->|Payjoin receive network selection| RECEIVE
    SETTINGS -->|typed import navigation| WALLET_IMPORT
    WALLETS -->|public import input and failures| WALLET_IMPORT
    WALLET_IMPORT -->|public QR and NFC scanning| SCANNING
    WALLET_IMPORT --> MNEMONIC_ENTRY
    WALLET_IMPORT --> SIGNERS
    WALLET_IMPORT --> BULL_UI
    WALLET_IMPORT --> SECRETS
    WALLET_IMPORT --> ELECTRUM
    WALLET_IMPORT --> SYNC
    WALLET_IMPORT --> PREFERENCES
    SCANNING --> BULL_UI
    RECEIVE[Receive routes, requests and address selection<br/>Workspace Feature]
    TRANSFER[Transfer]
    TX_HISTORY[Transactions<br/>Workspace Feature]

    ADDRESS_LABELS[Address View<br/>Workspace Member]
    SETTINGS -->|typed navigation| ADDRESS_LABELS
    ADDRESS_LABELS --> BULL_UI
    ADDRESS_LABELS --> LABEL_EDITOR
    ADDRESS_LABELS --> MEMPOOL
    ADDRESS_LABELS --> BULL_LOGGER
    ADDRESS_LABELS --> LABELS
    ADDRESS_LABELS --> PRIMITIVES
    ADDRESS_LABELS -->|typed wallet inventory| SECRETS
    ADDRESS_LABELS --> SYNC
    ADDRESS_LABELS --> SATOSHIFIER[Satoshifier Package]
    ADDRESS_LABELS -->|regtest Payjoin URI| BULL_PAYJOIN
    ADDRESS_LABELS -->|destination scanning| SCANNING
    ADDRESS_LABELS -->|scan and clear labels| SP
    ADDRESS_LABELS --> PREFERENCES
    WALLETS -->|transfer address selection| RECEIVE
    RECEIVE --> ADDRESS_LABELS
    RECEIVE --> LABELS
    RECEIVE --> PRIMITIVES
    RECEIVE --> BULL_LOGGER
    RECEIVE --> BULL_PRICER
    RECEIVE --> PREFERENCES
    BG_TASKS[Background Tasks Package]
    LIMIT_ORDERS[Limit Orders]
    COINS[Coins / UTXOs]
    ANNOUNCEMENTS[Announcements<br/>Workspace Feature]
    ALL_SEED_VIEW[All Seed View<br/>Workspace Feature]
    SP[Silent Payments<br/>Workspace Feature]

    %% Dependencies to Core (all features depend on Core, but showing it explicitly would clutter the diagram)
    %% Instead, we note this in the documentation below

    %% Extracted package dependencies
    BULL_UI[Design System Package]
    BULL_UI --> PRIMITIVES
    SETTINGS --> BULL_UI
    CORE --> PRIMITIVES
    CORE --> BULL_LOGGER
    LOGS --> BULL_LOGGER
    LOGS --> PRIMITIVES
    LOGS --> BULL_UI
    SETTINGS --> LOGS
    MERCHANT_MAP[BTC Map<br/>Workspace Feature: merchants, cache, map, list and search]
    MERCHANT_MAP --> BULL_LOGGER
    MERCHANT_MAP --> PRIMITIVES
    MERCHANT_MAP --> BULL_UI
    CORE --> BULL_PAYJOIN
    BULL_PAYJOIN --> PRIMITIVES
    BULL_PAYJOIN --> SYNC
    BULL_PAYJOIN --> BULL_LOGGER
    CORE --> BULL_PRICER
    BULL_PRICER --> PRIMITIVES
    CORE -->|price and chart composition| BTC_PRICE
    BTC_PRICE --> BULL_PRICER
    BTC_PRICE --> BULL_UI
    BTC_PRICE --> BULL_LOGGER
    BTC_PRICE --> PRIMITIVES
    SWAPS_PKG[Swaps Package<br/>Boltz engine, public Exchange orders and autoswap policy]
    SWAPS_PKG --> PRIMITIVES
    SWAPS_PKG --> BULL_LOGGER
    SWAPS_PKG --> ELECTRUM
    SWAPS_PKG --> FEES_PACKAGE
    SWAPS_PKG --> PREFERENCES
    SWAPS_PKG --> SECRETS
    SWAPS_PKG --> SYNC
    SWAPS[Swap and AutoSwap<br/>Workspace feature]
    SWAPS --> SWAPS_PKG
    SWAPS -->|order labels and navigation| TX_HISTORY
    SWAPS -->|balance, coins and spend admission| SYNC
    SWAPS -->|wallet inventory| SECRETS
    SWAPS -->|fund and broadcast| SPEND
    SWAPS -->|fees| FEES_PACKAGE
    SWAPS -->|destination input, receive and refund addresses| ADDRESS_LABELS
    SWAPS -->|Ark transfer recipient address| RECEIVE
    SWAPS -->|hardware signer metadata| SIGNERS
    SWAPS -->|coin selection sheet| COINS
    SWAPS --> BULL_UI
    SETTINGS -->|typed settings navigation| SWAPS
    SEND --> SWAPS_PKG
    RECEIVE --> SWAPS_PKG
    TX_HISTORY --> SWAPS_PKG
    SWAPS_PKG --> SYNC
    WALLETS --> SWAPS_PKG
    SETTINGS --> SWAPS_PKG
    ALL_SEED_VIEW --> SWAPS_PKG
    APP_STARTUP --> SWAPS_PKG
    RECEIVE --> BULL_PRICER
    SEND --> BULL_PRICER
    SWAPS --> BULL_PRICER
    HW_WALLETS --> SCREEN_AWAKE
    SCREEN_AWAKE --> BULL_LOGGER
    SCREEN_AWAKE --> WAKELOCK_PLUS

    %% Optional exchange access and wallet quick actions
    CORE -->|standalone startup and pending choices| WIZARD
    WIZARD -->|initial access choice| EXCHANGE_DOMAIN
    WIZARD -->|Exchange option| BULL_EXCHANGE
    CORE -->|wizard platform availability| EXCHANGE_DOMAIN
    WIZARD --> PREFERENCES
    WIZARD --> BULL_UI
    WIZARD --> BULL_PRICER
    WIZARD --> BULL_LOGGER
    WIZARD --> PRIMITIVES
    WIZARD -->|store vocabulary| NOVLANG[Novlang Package]
    SETTINGS --> QUICK_ACTIONS
    WALLETS --> QUICK_ACTIONS
    QUICK_ACTIONS --> BULL_UI
    QUICK_ACTIONS --> PRIMITIVES
    ONBOARDING --> WALLET_IMPORT
    ONBOARDING --> MNEMONIC_ENTRY
    APP_STARTUP --> MNEMONIC_ENTRY
    MNEMONIC_ENTRY --> BULL_UI
    BACKUPS --> PHYSICAL_BACKUP_VERIFICATION
    PHYSICAL_BACKUP_VERIFICATION --> BULL_UI
    PHYSICAL_BACKUP_VERIFICATION --> SECRETS
    ONBOARDING --> SETTINGS
    ONBOARDING --> WALLETS

    %% Legacy Core-to-feature dependencies, pending extraction

    %% Feature-to-feature dependencies (extracted from draw.io diagram)
    ALL_SEED_VIEW --> ACCESS
    ALL_SEED_VIEW --> SECRETS
    ALL_SEED_VIEW --> PREFERENCES
    ALL_SEED_VIEW --> BULL_UI
    SETTINGS -->|recovery phrase viewer route| ALL_SEED_VIEW
    CORE -->|wallet home composition| ANNOUNCEMENTS
    ANNOUNCEMENTS --> BULL_UI
    ANNOUNCEMENTS --> PRIMITIVES
    APP_STARTUP --> SECRETS
    APP_STARTUP --> ACCESS
    SETTINGS --> ACCESS
    APP_STARTUP --> LOGS
    APP_STARTUP --> TOR
    BIP85 --> SECRETS
    BIP85 --> PREFERENCES
    BIP85 --> BULL_UI
    SETTINGS -->|derivation history route| BIP85
    APP_STARTUP --> RECOVERBULL
    WALLETS -->|signer device properties| SIGNERS
    WALLETS --> RECOVERBULL
    BACKUPS --> RECOVERBULL
    SETTINGS -->|start backup| BACKUPS
    WALLETS -->|backup card and navigation| BACKUPS
    BACKUPS --> BULL_UI
    BACKUPS --> SECRETS
    BACKUPS --> ACCESS
    BACKUPS --> LABEL_EDITOR
    BACKUPS --> PREFERENCES
    BACKUPS --> SCREEN_PRIVACY
    WALLETS --> BTC_PRICE
    COINS --> BTC_PRICE
    SETTINGS --> BTC_PRICE
    COINS --> UTXO_MGMT
    COINS --> LABELS
    COINS -->|address viewer| ADDRESS_LABELS
    SEND --> LABELS
    RECEIVE --> LABELS
    SETTINGS --> LABELS
    COINS -->|public revision stream and coins| SYNC
    COINS -->|authorized wallet identity| SECRETS
    COINS -->|legacy foreground refresh| WALLETS
    SETTINGS --> SWAPS
    SETTINGS --> EXCHANGE
    SETTINGS --> TX_HISTORY
    LIMIT_ORDERS --> EXCHANGE
    EXCHANGE -->|Buy and withdrawal order details navigation| TX_HISTORY
    SUPPORT -->|support chat navigation| BULL_EXCHANGE
    TX_HISTORY -->|exchange orders and recorded fiat amounts| EXCHANGE
    LIMIT_ORDERS -->|funding navigation and amount input| BULL_EXCHANGE
    LIMIT_ORDERS -->|opens order details| BULL_EXCHANGE
    HW_WALLETS --> CORE
    CORE --> LABELS
    RECEIVE --> BULL_PAYJOIN
    RECEIVE -->|typed wallet inventory| SECRETS
    RECEIVE -->|exact-network wallet balances| SYNC
    SETTINGS -->|Payjoin disclosure widget| RECEIVE
    SWAPS -->|legacy Lightning fallback uses receive values| RECEIVE
    WALLETS -->|typed receive navigation| RECEIVE
    RECEIVE --> TX_HISTORY
    SEND -->|signed transaction handoff and consolidation status| SEND_TOOLS
    SEND --> FEES_UI
    SEND --> NETWORK
    SEND --> BULL_PAYJOIN
    SEND --> SP
    SEND --> SWAPS
    SEND --> TX_HISTORY
    SEND --> UTXO_MGMT
    SEND -->|public coin management route| COINS
    SEND -->|public spend admission and revisions| WALLETS
    SETTINGS -->|public wallet discovery| WALLETS
    SETTINGS -->|swap rescue wallet choices| SECRETS
    SETTINGS --> CORE
    SETTINGS --> BULL_PAYJOIN
    SETTINGS --> RECOVERBULL
    SETTINGS -->|service health and navigation| NETWORK
    NETWORK --> TOR
    NETWORK --> BULL_UI
    NETWORK --> BULL_PRICER
    NETWORK --> BULL_PAYJOIN
    NETWORK --> RECOVERBULL
    NETWORK --> PRIMITIVES
    ONBOARDING --> NETWORK
    SWAPS --> LABELS
    SETTINGS --> SP
    SETTINGS -->|await foreground regtest provisioning before selection| ELECTRUM
    %% Silent receives a foreground flag; swap owns the scheduling port implemented by wallet.
    WALLETS -->|account snapshots and sync| SP
    CORE -->|exact-network fingerprint and wallet presentation composition| SP
    SP --> PREFERENCES
    SP --> PRIMITIVES
    SP --> BULL_UI
    SP --> BULL_LOGGER
    CORE --> TOR
    ELECTRUM --> TOR
    WALLETS --> TOR
    WALLETS --> NETWORK
    RECOVERBULL --> TOR
    RECOVERBULL --> SECRETS
    RECOVERBULL --> PREFERENCES
    RECOVERBULL --> LEGACY_STORAGE
    RECOVERBULL --> PRIMITIVES
    RECOVERBULL --> BULL_LOGGER
    RECOVERBULL --> BULL_UI
    RECOVERBULL --> SCREEN_PRIVACY[Screen Privacy]
    SWAPS -->|consolidation status and route| SEND_TOOLS
    TRANSFER --> RECEIVE
    TX_HISTORY --> BULL_PAYJOIN
    TX_HISTORY -->|wallet history projections and revisions| SYNC
    WALLETS -->|wallet detail history widgets| TX_HISTORY
    UTXO_MGMT --> LABELS
    UTXO_MGMT --> WALLETS
    WALLETS -->|consolidation banner| SEND_TOOLS
    SETTINGS -->|signed transaction reader| SEND_TOOLS
    WALLETS --> HW_WALLETS
    WALLETS --> NETWORK
    WALLETS --> SECRETS
    SP --> SECRETS
    WALLETS --> SETTINGS
    WALLETS -->|public orders + swap scheduling port| SWAPS

    %% Reviewed source dependencies exposed by network owner moves (2026-11-07)
    MEMPOOL[Mempool Package<br/>Servers, validation and explorer links]
    MEMPOOL --> PRIMITIVES
    MEMPOOL --> TOR
    MEMPOOL --> BULL_LOGGER
    CORE -->|composes schema 16 tables| MEMPOOL
    SETTINGS -->|typed settings failures| MEMPOOL
    FEES_PACKAGE -->|active fee service base| MEMPOOL
    SP --> MEMPOOL
    TX_HISTORY --> MEMPOOL
    WALLETS --> MEMPOOL
    APP_STARTUP --> PREFERENCES
    APP_STARTUP --> PROVISIONING[Default Wallet Provisioning]
    PROVISIONING --> SECRETS
    PROVISIONING --> PRIMITIVES
    PROVISIONING --> BULL_LOGGER
    APP_STARTUP --> BULL_PAYJOIN
    EXCHANGE -->|shared destination validation and input| ADDRESS_LABELS
    WALLETS --> FEES_PACKAGE
    SEND --> FEES_PACKAGE
    SEND_TOOLS --> FEES_PACKAGE
    CORE --> FEES_PACKAGE
    LIMIT_ORDERS -->|public destination input| ADDRESS_LABELS
    SEND --> SIGNERS
    SEND_TOOLS --> FEES_UI
    SEND_TOOLS --> BULL_UI
    SWAPS --> FEES_PACKAGE
    CORE -->|WalletFacade reads for network status| WALLETS
    SWAPS --> FEES_UI
    WIZARD -->|translation warning| SETTINGS_HUB
    APP_STARTUP -->|translation warning| SETTINGS_HUB
    ONBOARDING -->|translation warning| SETTINGS_HUB


    %% Wallet readers and spend preparation assigned to their app owners
    UTXO_MGMT --> SYNC
    SWAPS --> ADDRESS_LABELS
    SEND --> ADDRESS_LABELS
    WALLETS -->|address viewer| ADDRESS_LABELS
    COINS -->|coin selection address viewer| ADDRESS_LABELS
    EXCHANGE -->|address viewer| ADDRESS_LABELS
    TX_HISTORY -->|address viewer| ADDRESS_LABELS
    SEND_TOOLS -->|address viewer| ADDRESS_LABELS

    %% Styling
    classDef coreStyle fill:#2d3748,stroke:#4a5568,stroke-width:3px,color:#fff
    classDef packageStyle fill:#234e52,stroke:#319795,stroke-width:2px,color:#e6fffa
    classDef featureStyle fill:#1a202c,stroke:#2d3748,stroke-width:2px,color:#e2e8f0

    class CORE coreStyle
    class SECRETS,PRIMITIVES,BULL_PAYJOIN,BULL_PRICER,TOR,SCREEN_AWAKE,SWAPS_PKG,BULL_UI,ARK_PROTOCOL,FEES_PACKAGE packageStyle
    class WALLET_IMPORT,SCANNING,ONBOARDING,SETTINGS,ACCESS,LABEL_EDITOR,HW_WALLETS,BTC_PRICE,NETWORK,BIP85,FEES_UI,WALLETS,OVERVIEW,EXCHANGE,BULL_EXCHANGE,SUPPORT,APP_STARTUP,UTXO_MGMT,ADDRESS_LABELS,BACKUPS,SWAPS,SEND,SEND_TOOLS,RECEIVE,TRANSFER,TX_HISTORY,BG_TASKS,LIMIT_ORDERS,COINS,ANNOUNCEMENTS,ALL_SEED_VIEW,SP,MERCHANT_MAP,ARK,WIZARD featureStyle
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

## Foreground synchronization

Wallet owns the private foreground synchronization queue and consumes the Silent capability and the Swap activity capability. Silent receives an explicit foreground-start flag from composition. Swap's watcher calls its own scheduling usecase and port; wallet implements that published port. Runtime callbacks enter the wallet queue without introducing a Silent/swap source dependency on wallet synchronization. The Swap activity capability keeps its direct refresh path so a queued pass never enqueues itself.

The wallet and wallet address repositories live in `lib/features/wallet/data`. Swap reads wallet selection from Secrets and wallet balances, coins and spend admission from Sync. The wallet synchronizer calls the mounted Swap activity capability to refresh orders. `test/architecture/foreground_sync_dependencies_test.dart` resolves the remaining app feature edges through imports and transitive exports.

## Core Dependencies

**Important**: All features implicitly depend on Core for foundational services. These dependencies are not shown in the diagram to reduce visual clutter.

### What Core Provides

1. **Infrastructure Services**:

   - Database (Drift/SQLite)
   - Secure Storage instance (Flutter Secure Storage)
   - API Clients (REST/GraphQL clients)
   - Embedded Onion adapter with isolated RecoverBull and Bitcoin Electrum `.onion` sessions
   - Explicit local SOCKS5 override for Bitcoin Electrum and encrypted backups
   - DI setup and interfaces (Service Locator pattern)
   - Router setup and interfaces (Navigation)
   - PIN encrypted storage

2. **Core Primitives**:
   - Canonical location: `packages/primitives`; compatibility exports remain in `lib/core` during migration.
   - Generic iterable and date extensions are available from `package:primitives/generic_extensions.dart`.
   - Extracted examples: `Failure`, `Result`, `Fingerprint`, network types, `Outpoint`, `Sats`, `FeeRate`, and `XpubType`. Security-domain types such as `Secret` now live in `packages/secrets`, which owns them rather than exposing them as primitives.
   - The app uses `ConvertAmount` and `FormatAmount` from `primitives` for BTC, satoshi and fiat conversions and display.
   - Shared types used across multiple features, avoiding redundant definitions
   - The app and `satoshifier` share millisatoshi-to-satoshi conversion through `primitives`.
   - Immutable, validated value objects that ensure domain integrity
   - The app and `swaps` share string formatting and percentage calculation through `primitives`.

> Migration note: `lib/core` is shared infrastructure (no business logic). Shared *domain* modules that historically landed in `lib/core/<domain>` (e.g. `wallet`) graduate into `packages/<domain>` under the melos workspace — each exposing its repository interfaces + domain types + shared use-cases through a public API, never a bloc or screen. See [ARCHITECTURE.md](ARCHITECTURE.md).

Shared widgets are published by `bull_ui`. App-specific screens, adapters and localized content belong to their respective features. The late-2026 UI migration removed the shared Core widget and screen directories.

## Key Dependency Patterns

### Central Features (Highly Depended Upon)

- **Core**: Foundation for all features
- **Store vocabulary**: `packages/novlang` — the real words live in the root catalogue; `novlang` holds sparse per-store overrides (`novlang_<lang>.arb`, listed in `manifest.yaml`) and the pure `resolveNovlangPolicy(platform, isSuperuser)`. `tools/novlang_bridge.dart` (run by `make translations`) generates the `AppLocalizations` subclasses and `NovlangAppLocalizationsDelegate` that the shell composes before `AppLocalizations.delegate`. A new user-visible word a store forces is added to the manifest and to all 27 `novlang_<lang>.arb`; nothing else in the app chooses vocabulary.
- **Tor**: `packages/bull_tor` — embedded Onion lifecycle with isolated RecoverBull and Bitcoin Electrum `.onion` sessions, plus provider-agnostic local SOCKS5 verification. Depends on Flutter for app-directory storage and an iOS plugin that excludes Tor state from backups, which are infrastructure-package exceptions in AGENTS.md
- **Wallets**: Used by Send, UTXO Management, Transaction History, App Startup
- **Secrets** (workspace package): Used by Wallets, BIP85, App Startup, All Seed View, RecoverBull, Swaps, Silent Payments
- **Settings**: Used by Wallets, Bitcoin Price
- **Swaps** (workspace package `packages/swaps`): `Swaps.open` owns the Boltz engine, its network transitions and the provider and autoswap settings. Its stable `SwapStore`, `SwapResolver` and `BoltzSwaps` handles survive provider replacement. `SwapRouting` resolves the operator choices for Send, Receive, transfers and AutoSwap; the settings narrow view exposes typed reads and writes.
- **Swap and AutoSwap** (workspace feature `features/swap`): `SwapFeature.mount` contributes transfer, confirmation, progress and swap settings, and provides the AutoSwap settings route under Settings. Transfer and AutoSwap use Spend for funding and submission and use the typed order operations published by `swaps` for Exchange fallback.
- **Recipient selection and activation**: Owned by Bull Exchange and used by Pay, Sell and Withdrawal
- **UTXO Management**: Used by Send, Swaps, Payjoin

### Leaf Features (Depend on Many, Few Depend on Them)

- **Send**: Depends on Spend, Fees, Network, Payjoin, Swaps, UTXO Management, Wallets
- **Receive**: Depends on Payjoin, Swaps
- **Receive and Address View capabilities**: `features/receive` mounts the existing Bitcoin, Liquid, Lightning and Payjoin routes. It reads the authorized Secrets inventory, native Sync balances and Signers associations, observes payments through Transactions, and watches order status through Swaps. `features/address_view` mounts address history under Settings and owns indexed reads, address issuance and label enrichment. The shell binds existing wallet polling, post-payment sync and Settings consent; `SwapFeature` creates Lightning-to-Liquid fallback orders.
- **Backups**: Uses the Secrets wallet inventory and the RecoverBull backup facts

### Exchange-Related Features

- **Exchange, Exchange Settings, Default Wallets, Buy, Sell, Pay, Withdraw, DCA, Transaction History, Funding and Limit Orders** use `packages/exchange` for exchange operations. The package maps the authenticated BBX transport to owned values and typed failures. Exchange also owns general recipient management and default payout operations. Wire JSON and protocol exceptions stay internal.

- **Buy, Sell, Funding**: All depend on Exchange

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

## Optional exchange access and quick actions

`exchange` owns access, authentication, policy and cleanup behind its public facade. Its repository serializes credential and socket operations, publishes a sealed access state, and invalidates stale work with one internal epoch. The installation-wide exchange_access preference contains only enabled and signOutPending; session is derived from environment-scoped credentials. A current server 401 expires the captured environment while keeping exchange enabled. Explicit sign-out journals cleanup and attempts both keys and cookies; unreadable preferences never prevent Reset. Wizard choices apply only before a newer explicit decision. iOS platform restrictions hide activation and trading, while support authentication and authenticated account management remain available. Initial unresolved access stays hidden on Home; reconciliation keeps the resolved view and the trading guard waits for the lifecycle queue. Inferred activation and 401 expiration persist enabled=true before credential loss. No Drift migration is added.

`features/quick_actions` owns the catalogue, defaults, Home/More layout, drag editor and a shared QuickActionsCubit. Thin Load/Save/Reset use cases separate the cubit from persistence, and the module composition constructs their repository. Settings supplies its storage adapter, the platform's default row (iosDefaults on iOS, defaults elsewhere, both owned by the package) and an exchangeVisible stream derived from the public exchange availability policy and platform changes. Wallet and the settings editor share that cubit and receive navigation callbacks from the shell. The package depends on bull_ui, primitives and the existing bloc library; it imports no exchange, settings or routing implementation. Home contains at most three actions plus More whenever another available action is hidden, with Settings as a display-only fallback. Immediate writes are serialized, failures restore the draft, and Restore defaults offers revision-scoped Undo. Known unavailable choices remain stored. Only the unversioned {home, more} preference format is read and written, under quick_actions; intermediate debug formats are not migrated. Bull components own button, stream-value and drag-list presentation. The exchange identifier is displayed as Trade. Public price history remains independent; WalletHome has no bottom tabs or top action buttons.

The mnemonic import feature currently imports Wallets internals. Replace that dependency with the Wallets public facade in a scoped follow-up; the graph records the existing dependency rather than implying facade compliance.

## Wallet failure compatibility edges (2026-11-08)

At composition, the app wallet owner supplies the default wallet environment and the network feature turns read failures into a localized service-status error. The former `lib/core/wallet` paths are gone.

## Networks source-edge review (2026-11-08)

The architecture test records source dependencies, including internal imports and compatibility exports. The original review compared 46 additions against the rebased networks tree. The table shows the surviving source edges from that review after subsequent workspace extractions. They are not permission for new internal imports. Existing cycles and internal boundaries remain migration debt; broad facade extraction is separate work. The captured-network changes below retain the current API and avoid an unrelated feature migration. The diagram and the exact allowlist in `test/architecture/foreground_sync_dependencies_test.dart` record the same observed additions.

| Source → owner | Provenance and reason retained | Observed import/export path |
|---|---|---|
| `default_wallets → wallet` | Owner relocation: Keep existing wallet identity, catalog, metadata or address presentation attached to its relocated owner. | `lib/features/default_wallets/ui/widgets/default_wallets_editor.dart -> lib/features/wallet/ui/widgets/address_viewer.dart` |
| `exchange → settings` | Owner relocation: Keep the existing environment/preferences consumer attached to the relocated settings owner. | `lib/features/exchange/ui/screens/exchange_auth_screen.dart -> lib/features/settings/domain/settings_entity.dart` |
| `settings → wallet_import` | Opens the import hub through its typed navigation. The shell supplies the active environment for hardware visibility. | `lib/features/settings/ui/settings_item.dart -> package:wallet_import/wallet_import.dart` |
| `limit_orders → wallet` | Owner relocation: Keep existing wallet identity, catalog, metadata or address presentation attached to its relocated owner. | `lib/features/limit_orders/limit_orders_locator.dart -> lib/features/wallet/domain/usecases/get_wallets_usecase.dart` |
| `pay → settings` | Owner relocation: Keep the existing environment/preferences consumer attached to the relocated settings owner. | `lib/features/pay/ui/screens/pay_receive_payment_screen.dart -> lib/features/settings/domain/settings_entity.dart` |
| `sell → settings` | Owner relocation: Keep the existing environment/preferences consumer attached to the relocated settings owner. | `lib/features/sell/ui/screens/sell_success_screen.dart -> lib/features/settings/domain/settings_entity.dart` |
| `send → settings` | Owner relocation: Keep the existing environment/preferences consumer attached to the relocated settings owner. | `lib/features/send/ui/widgets/coin_selection_bottom_sheet.dart -> lib/features/settings/domain/settings_entity.dart` |
| `settings → swaps` | Restore and rescue use the public swap engine capability. | `lib/features/settings/ui/screens/bitcoin/swap_restore_screen.dart -> package:swaps/swaps.dart` |
| `wizard → settings` | The standalone wizard uses the Settings member's public translation warning. | `features/wizard/lib/src/ui/widgets/customize_step.dart → package:settings/settings.dart` |

| `app_startup → mnemonic_entry` | Restore UI uses the typed input widget to preserve explicit language selection. | `restore_default_secret_screen.dart → package:mnemonic_entry/mnemonic_entry.dart` |
| `onboarding → mnemonic_entry` | Recovery UI uses the same typed input widget instead of duplicating language selection. | `onboarding_physical_recovery.dart → package:mnemonic_entry/mnemonic_entry.dart` |

The former `broadcast_signed_tx → settings` allowance is removed: broadcast now carries the captured wallet network instead of reading the mutable global environment. Develop also retires the four price-registration edges from buy, receive, send and swap; their allowances and diagram edges are removed.

Develop also removes the price chart’s shell locator import and its obsolete exception from `shell_imports_test.dart`. Secrets owns BIP85 allocations, historical records and re-derivation. The BIP85 workspace feature uses the active Preferences environment and the Bitcoin default from the authorized inventory. Ark reads historical derivation metadata, including revoked rows, directly through the same Secrets registry.

## RecoverBull public navigation and owner edges (2026-11-13)

RecoverBull navigation is a public, stateless module entry point; onboarding, backup options and settings do not fetch the root locator. Composition substitutes native initialization through TorNativeInitializer while retaining the real Tor registrations. The source graph records published RecoverBull facade dependencies from app_startup, network, backups and wallet. Retired RecoverBull/Google Drive and autoswap-to-settings edges are removed; architecture guards retain their assertions. Startup restore and onboarding consume the mnemonic entry member directly. Onboarding also uses the read-only Bitcoin history scan published by Wallet Import.


## Regtest Electrum storage and watch-only import

Electrum owns foreground preparation of its current-schema storage and exposes it through `electrum.foregroundStorage` (`package:electrum/setup.dart`). Startup passes the single normalized Settings snapshot through SettingsBootstrap before awaiting this passive barrier; it performs no network IO. Regtest provisions both Bitcoin and Liquid rows in one idempotent transaction, preserves custom endpoints and options, and replaces only obsolete managed defaults. The regtest endpoint host comes from BULL_REGTEST_HOST at build time, with a loopback default, and is read only for a captured regtest selection. Mainnet/testnet preparation validates both production views for their existing hot switch and never creates fixture rows. Background entry points inspect readiness without seeding or repairing storage.

`ImportFeature.mount` contributes the import hub, mnemonic entry and confirmation, watch-only scanning and confirmation, and hardware instructions. The member owns their translations. Mnemonic duplicate checks still read the unlocked Secrets inventory scoped to the active Bitcoin network. Composition supplies the existing foreground Wallet provisioning methods directly; Wallet retains custody admission, catalog insertion and native creation.

Watch-only import captures the selected Bitcoin environment before parsing. Test-family public-key versions may represent testnet or regtest; the captured selection resolves that ambiguity while preserving the public key. Regtest accepts software BIP84 watch-only input, retains the original network identity and refuses hardware provenance or a mainnet key. The existing capability policy controls explorer actions and Lightning availability. Receive uses that same Lightning capability when choosing its initial Liquid/Lightning mode, so a regtest Liquid wallet opens a supported selection.

Mnemonic scanning preserves the wallet owner's typed unsupported-script refusal. The import UI disables continuation for that result instead of offering an import that cannot succeed. These changes add no database revision and do not enable swaps or Payjoin on regtest by themselves.

## Shared payment destination input

Wallet publishes destination validation and input through `public/payment_destination.dart`. The app binds this public surface to Buy, DCA and default payouts; Limit Orders and Swap consume it directly. The adapter retains the complete scanned request, applies each consumer’s accepted payment types and displays the existing AddressViewer. The visual component remains pure UI in bull_ui. The legacy core scanner file, unreachable Send request-identifier route and duplicate Swap scanner are removed; consumers import the published Wallet capability directly.

## Owner-scoped keychain capabilities

`packages/secrets` owns the legacy OS keychain through closed access, exchange, Silent Payments and swap capabilities. Access compares the PIN internally; no stored PIN leaves the package. Consumers select a capability rather than a key or arbitrary prefix. The generic `lib/core/storage` secure key-value datasource and its custody exception are removed. Existing keys and Android/iOS plugin options are preserved, with no data migration. Silent Payments configuration remains in its existing keychain entries even though it is not secret.

`packages/swaps` depends directly on `secrets`: `SwapStorage` owns the legacy `swap_` key composition and maps `SwapKeychain` failures inside the engine. Composition injects the closed capability directly, with no feature-owned secret-store bridge. Its regtest view shares the canonical capability and fingerprint allocation locks; only swap blobs use the separate `swap_regtest_` namespace.

## Signer ownership (2026-11-20)

`features/signers` replaces the Ledger, BitBox and PSBT-flow owners. Import consumes public accounts; Send and Receive pass the wallet network. Scanning and wallet import consume the published URQR/device types. Signers owns its routes and route error rendering. The shell composes the mounted routes and supplies the NFC writer callback, so signers has no scanning, wallet, settings or import dependency. Existing consumer edges to signer internals become edges to its public library; the retired reverse edges are removed. BBQR transaction decoding remains blocked on the shell-owned `BitcoinTx`; BBQR encoding is extracted.

## Network settings and service status

The settings hub, onboarding and wallet error actions use `NetworkNavigation`. The app mounts the network member once and adds its root routes and its nested Tor route. The settings hub owns its service-health use case and presentation, with a status session independent of the diagnostics screen. Network use cases call Electrum, Mempool, Preferences and Tor, as well as the Payjoin, Pricer and RecoverBull diagnostics capabilities. The network member requests a Bitcoin fee estimate from Fees with the Mempool source. The shell supplies the default wallet environment and Tor requirement through WalletFacade. Background Electrum composition remains independent of the network UI.

## Wallet-independent transaction values

`packages/sync` owns the Bitcoin and Liquid transaction values formerly in `lib/core/transactions`. Transaction review consumes `package:sync/transactions.dart`; wallet-history projections remain in `package:sync/sync.dart`. The separate entry libraries distinguish transaction review values from wallet-relative history without compatibility exports in the app.

### Direct chain capability consumers

Send uses `sync.broadcastLiquidTransaction` for wallet-independent Liquid broadcasts. Transactions uses the sync chain queries and broadcasts for Payjoin, with the published connection port supplied by composition. These paths no longer depend on the app blockchain datasource or the Liquid forwarding repository.

### Native runtime extraction

The wallet module supplies inventory and protocol ports to the runtime in `sync`. Ark and Payjoin consumers pass exact wallet keys to the same runtime instance. The global foreground queue still orders native, swap and Silent Payments work; catalog metadata and presentation enrichment stay outside sync.

Spend resolves exact wallet IDs in the admitted Secrets inventory and uses Sync for preparation, guarded submission and consolidation. Pay, Sell, transfers and AutoSwap use its typed results; fee review keeps the opaque preparation rather than reconstructing it from PSBT bytes. Payjoin holds its session lock while Spend and Sync admit and persist the exact original before relay publication. Imported Bitcoin remains wallet-free and uses the global freeze queue. Hardware signing stays with Signers. `bitcoinRecipientAmounts` owns PSBT recipient-script matching and remainder calculation in Sync.

### Wallet reader ownership

Sync publishes the wallet-relative native values and address usage. Address View derives and enriches addresses and retains the native issued-index watermark. Address View also supplies the common receive-address read, and Receive owns its flow-specific address decisions. Coins consumes the published coin and freeze state and enriches the coins with labels. The Transactions feature owns application history, including environment selection, wallet-relative presentation values and labels. It reads the live Secrets inventory, Sync projections, Payjoin sessions and Exchange orders. The shell supplies foreground sync activity and navigation for actions owned by other features. Import previews use Sync's descriptor scan directly. Send assembles spend requests, delegates native operations to Sync and requests software signatures from Secrets after protocol admission. Hardware signing stays with Signers.

The app owners still use the legacy catalog to resolve identity and access native handles. Shared application consumers now point to the address, coins, receive and transaction owners for the relocated rules and types. Existing composition and route dependencies remain until the catalog and feature extractions replace them.

## Access ownership

`features/access` replaces PIN Code and App Unlock. App Startup reads PIN status through `Access`, Settings uses the mounted PIN route, and Backup and All Seed View consume the typed reauthentication gate. `AccessFeature.mount` contributes root and settings routes once before startup; the host supplies lazy backup eligibility and navigation callbacks. Secrets retains PIN and failed-attempt storage. Access publishes one failure family while preserving the distinct unlock and PIN-settings locked messages.

## Encrypted database import foundation

The `legacy_storage` workspace member owns the historical application database, schema and migrations. The app and its remaining legacy consumers use `package:legacy_storage/app_database.dart`. The member depends on `primitives` for typed import results and uses Bull Logger and Bull Reporting for migration diagnostics. Module migration code can use it to copy a frozen legacy source into the owning database with a committed receipt. `secrets` can open a keyed Drift executor for an owner. Foreground startup now composes the split-v1 coordinator and Mempool participant before publishing Mempool's encrypted store. Background Tasks holds the same lifecycle admission until resource closure, and requests retry on incomplete setup or failed cleanup. Legacy Storage remains independent of Mempool; each owner implements the participant contract. Other owners retain their historical connections while the manifest is incomplete; this development coexistence never authorizes legacy retirement.

Secrets uses Legacy Storage for lifecycle admission and participates in split-v1 through its migration library. The encrypted Secrets store owns wallet definitions, derivation records and view access state. Sync's inventory composition library translates the descriptor projection to the native catalog contract.

Electrum also implements its import participant through `legacy_storage` and opens its encrypted store through `secrets`. Foreground and background connection/cache consumers use that store; historical tables remain only for the legacy migration chain.

Labels implements its participant through `legacy_storage`, opens its encrypted store through `secrets`, and supplies Sync with its owner-built freeze and reserved-address ports. Label, Payjoin and BIP-329 consumers share that authority.

Preferences owns an encrypted schema-1 settings and RecoverBull permission store, with row/sequence/import-receipt atomicity. It preserves consent only for the default RecoverBull URL and never stores the source URL. Only the testnet credential projection borrows the tracked legacy connection; Announcements owns its encrypted dismissal store. Foreground prepares under exclusive cutover admission; foreground and consuming background tasks open existing Preferences under shared admission and receipt checks. The legacy and standalone RecoverBull files are retained.


## Recovery phrase display

Settings mounts All Seed View as a workspace route. Access supplies reauthentication, Secrets supplies the active catalog and guarded seed deletion, and Swaps supplies the sealed swap phrase widget. Wallet recovery phrases and passphrases stay in Secrets’ MnemonicView. Screen protection must succeed before the viewer builds, and neither phrase renderer contributes words to accessibility semantics.

## Backup verification ownership

Backups mounts the status, options and physical verification routes and provides the wallet home backup card. It reads the default Bitcoin wallet from the active Secrets inventory and the backup facts keyed by its local secret from RecoverBull. Physical Backup Verification validates the mnemonic and passphrase before Backups records completion against the verified secret in RecoverBull. Access continues to read backup eligibility for default wallets in the active environment.
