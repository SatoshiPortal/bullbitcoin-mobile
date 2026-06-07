# Feature Dependencies

This diagram shows the dependencies between features in the Bull Bitcoin Mobile application. It helps visualize the dependency graph and ensures there are no cyclic dependencies.

**Diagram Type**: This is a **Package Dependency Diagram** (also known as Module Dependency Graph or Component Dependency Diagram in UML).

## Module Dependency Graph

```mermaid
graph TB
    %% Core infrastructure
    CORE[Core<br/>---<br/>Database, Secure Storage,<br/>API Clients, Tor HTTP Client, UI Kit,<br/>DI & Router setup,<br/>PIN encrypted storage,<br/>Domain Primitives/Value Objects]

    %% Feature modules
    SETTINGS[Settings]
    TOR[Tor]
    PIN_CODE[Pin Code]
    LABELS[Labels]
    SECRETS[Secrets]
    HW_WALLETS[Hardware Wallets]
    BTC_PRICE[Bitcoin Price]
    BTCPAY[BTCPay]
    NETWORK[Network]
    BIP85[BIP85]
    BIP85_REGISTRY[BIP85 Registry]
    DETERMINISTIC_WALLETS[Deterministic Wallets]
    KEYCHAIN_MANIFEST[Keychain Manifest]
    KEYCHAIN_RECOVERY[Keychain Recovery]
    NOSTR_IDENTITY[Nostr Identity]
    BULLNYM[Bullnym]
    FEES[Fees]
    WALLETS[Wallets]
    EXCHANGE[Exchange]
    APP_STARTUP[App Startup]
    UTXO_MGMT[UTXO Management]
    ADDRESS_MGMT[Address Management]
    RECIPIENTS[Recipients]
    FUNDING[Funding]
    BACKUPS[Backups]
    SWAPS[Swaps]
    PAYJOIN[Payjoin]
    WITHDRAWAL[Withdrawal]
    STATUS[Status]
    SEND[Send]
    RECEIVE[Receive]
    TRANSFER[Transfer]
    TX_HISTORY[Transaction History]
    BG_TASKS[Background Tasks]
    AUTOSWAPS[AutoSwaps]
    AUTOSWEEP[AutoSweep]
    DCA[DCA]
    SELL[Sell]
    PAY[Pay]
    BUY[Buy]
    COINS[Coins / UTXOs]

    %% Dependencies to Core (all features depend on Core, but showing it explicitly would clutter the diagram)
    %% Instead, we note this in the documentation below

    %% Feature-to-feature dependencies (extracted from draw.io diagram)
    ADDRESS_MGMT --> LABELS
    APP_STARTUP --> WALLETS
    AUTOSWAPS --> TRANSFER
    AUTOSWEEP --> FEES
    AUTOSWEEP --> LABELS
    AUTOSWEEP --> WALLETS
    BIP85 --> SECRETS
    BIP85 --> SETTINGS
    BIP85 --> BIP85_REGISTRY
    BACKUPS --> BIP85
    BACKUPS --> TOR
    BACKUPS --> WALLETS
    BTC_PRICE --> SETTINGS
    BTCPAY --> BIP85_REGISTRY
    BTCPAY --> DETERMINISTIC_WALLETS
    BTCPAY --> KEYCHAIN_MANIFEST
    BTCPAY --> WALLETS
    KEYCHAIN_RECOVERY --> BIP85_REGISTRY
    KEYCHAIN_RECOVERY --> DETERMINISTIC_WALLETS
    KEYCHAIN_RECOVERY --> KEYCHAIN_MANIFEST
    NOSTR_IDENTITY --> BIP85_REGISTRY
    BUY --> EXCHANGE
    BUY --> RECEIVE
    COINS --> UTXO_MGMT
    COINS --> LABELS
    COINS --> WALLETS
    DCA --> RECEIVE
    DETERMINISTIC_WALLETS --> BIP85
    KEYCHAIN_MANIFEST --> BIP85_REGISTRY
    EXCHANGE --> SETTINGS
    FEES --> NETWORK
    FUNDING --> EXCHANGE
    HW_WALLETS --> CORE
    LABELS --> CORE
    PAY --> RECIPIENTS
    PAYJOIN --> UTXO_MGMT
    PIN_CODE --> CORE
    RECEIVE --> PAYJOIN
    RECEIVE --> SWAPS
    RECIPIENTS --> EXCHANGE
    SECRETS --> CORE
    SELL --> EXCHANGE
    SEND --> FEES
    SEND --> NETWORK
    SEND --> PAYJOIN
    SEND --> SWAPS
    SEND --> UTXO_MGMT
    SEND --> WALLETS
    SETTINGS --> BTCPAY
    SETTINGS --> CORE
    SWAPS --> UTXO_MGMT
    TOR --> CORE
    TRANSFER --> SEND
    TRANSFER --> RECEIVE
    TX_HISTORY --> PAYJOIN
    TX_HISTORY --> WALLETS
    UTXO_MGMT --> LABELS
    UTXO_MGMT --> WALLETS
    WALLETS --> BIP85
    WALLETS --> AUTOSWEEP
    WALLETS --> HW_WALLETS
    WALLETS --> NETWORK
    WALLETS --> SECRETS
    WALLETS --> SETTINGS
    WITHDRAWAL --> RECIPIENTS

    %% Styling
    classDef coreStyle fill:#2d3748,stroke:#4a5568,stroke-width:3px,color:#fff
    classDef featureStyle fill:#1a202c,stroke:#2d3748,stroke-width:2px,color:#e2e8f0

    class CORE coreStyle
    class SETTINGS,TOR,PIN_CODE,LABELS,SECRETS,HW_WALLETS,BTC_PRICE,BTCPAY,NETWORK,BIP85,BIP85_REGISTRY,DETERMINISTIC_WALLETS,KEYCHAIN_MANIFEST,KEYCHAIN_RECOVERY,NOSTR_IDENTITY,BULLNYM,FEES,WALLETS,EXCHANGE,APP_STARTUP,UTXO_MGMT,ADDRESS_MGMT,RECIPIENTS,FUNDING,BACKUPS,SWAPS,PAYJOIN,WITHDRAWAL,STATUS,SEND,RECEIVE,TRANSFER,TX_HISTORY,BG_TASKS,AUTOSWAPS,AUTOSWEEP,DCA,SELL,PAY,BUY,COINS featureStyle
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
   - Factory for a HTTP client to connect to Tor
   - UI Kit (shared widgets, theme)
   - DI setup and interfaces (Service Locator pattern)
   - Router setup and interfaces (Navigation)
   - PIN encrypted storage

2. **Core Primitives**:
   - Intended location: `/lib/core/primitives/` — the primitives layer is still being extracted (see AGENTS.md); not all of these types live there yet.
   - Examples: `Secret`, `SecretUsagePurpose`, `Fingerprint`, `Address`, `Amount`, etc.
   - Shared types used across multiple features, avoiding redundant definitions
   - Immutable, validated value objects that ensure domain integrity

> Migration note: `lib/core` is shared infrastructure (no business logic). Shared *domain* modules that historically landed in `lib/core/<domain>` (e.g. `wallet`, `secrets`) graduate into `packages/<domain>` under the melos workspace — each exposing its repository interfaces + domain types + shared use-cases through a public API, never a bloc or screen. See [ARCHITECTURE.md](ARCHITECTURE.md).

## Key Dependency Patterns

### Node Semantics

- **Wallets** covers the shared wallet domain (`lib/core/wallet`, graduating to `packages/wallet` under the melos migration) together with the wallet home feature (`lib/features/wallet`). An edge into WALLETS means a feature consumes wallet domain APIs; edges out of WALLETS come from either half of that fused node.
- The WALLETS <-> AUTOSWEEP pair is therefore not a real cycle: the wallet home feature (presentation) consumes the AutoSweep facade, while AutoSweep's data adapter consumes the core wallet domain. The melos split into separate nodes will make this two acyclic edges.

### Central Features (Highly Depended Upon)

- **Core**: Foundation for all features
- **Wallets**: Used by Send, UTXO Management, Transaction History, Backups, App Startup, BTCPay, AutoSweep
- **Secrets**: Used by Wallets, BIP85
- **Settings**: Used by Wallets, Exchange, BIP85, Bitcoin Price
- **Recipients**: Used by Pay, Withdrawal
- **UTXO Management**: Used by Send, Swaps, Payjoin

### Leaf Features (Depend on Many, Few Depend on Them)

- **Send**: Depends on Fees, Network, Payjoin, Swaps, UTXO Management, Wallets
- **Receive**: Depends on Payjoin, Swaps
- **AutoSwaps**: Depends on Transfer
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
