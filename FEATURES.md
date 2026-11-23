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
    ARK -->|funding and wallet display data| SYNC
    TX_HISTORY -->|Payjoin signing guard| ARK
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
    WALLETS -->|public QR scanning| SCANNING
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
