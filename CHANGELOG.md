# Changelog

All notable changes to Bull Bitcoin Mobile will be documented in this file.

---

## [6.11.0] - 2026-06-08

### New Features

- **Export transaction history to CSV**: Download your full transaction history (on-chain, Liquid, Lightning, swaps, payjoin) as a CSV file filtered by date range. ([#1363](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1363))
- **Payment descriptions**: Add a note to any payment so you remember what it was for. ([#1453](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1453))
- **Clearer broadcast screen**: Before broadcasting, the confirmation screen now shows receiving address, change address, amounts, and fees — even for hardware wallet transactions. Addresses and txids are expandable and copyable with links to a block explorer. ([#1247](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1247))
- **Automatic swap claim retries**: The "Retry Swap Claim" button is gone. The app now retries automatically in the background. ([#2134](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2134), [#1912](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1912))
- **Swap expiry reminder**: A warning now reminds you to complete swaps within 24 hours to avoid automatic refunds. ([#2119](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2119))
- **Smarter wallet sync**: The wallet syncs automatically when you open the app or return to the home screen, with a visible loading indicator instead of misleading zeros. ([#2132](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2132), [#2222](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2222), [#1409](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1409))
- **Electrum server reliability**: Your custom Electrum server is always used when configured. Health checks now test actual operations, not just ping. If your primary server fails, the app falls back to alternatives and tells you clearly. ([#1992](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1992), [#2000](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2000))
- **Done button on iOS keyboards**: Number keypads now include a Done button across send, receive, buy, sell, swap, fee, and settings screens. ([#2188](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2188))
- **Top-aligned dismissible notifications**: In-app notifications now appear at the top and can be swiped away in any direction.
- **Linux desktop (experimental)**: Bull Bitcoin Wallet can now run on Linux. Early preview for testers. ([#2171](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2171))
- **Android beta channel**: Install a separate "Bull Beta" app with distinct branding to test upcoming features without affecting your main wallet.
- **Reproducible builds progress**: Continued work toward fully reproducible builds for WalletScrutiny verification. ([#1390](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1390))

### Exchange & Payouts

- **Light/limited KYC users unblocked**: Users with light or limited verification can now use the exchange in Canada, Costa Rica, Argentina, and Europe. Previously only CAD accounts worked with limited KYC. ([#2195](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2195))
- **Funding methods fixed**: Resolved broken funding flows for Argentina bank transfer ([#2181](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2181)), Canada online bill payment ([#2182](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2182)), Costa Rica SINPE MOVIL ([#2184](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2184)), and corrected European SEPA subtitles and limits ([#2183](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2183)).
- **SINPE validation improved**: Phone numbers are validated immediately with clearer errors instead of waiting until you tap Next. ([#2104](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2104))
- **Recipient ID labels clarified**: ID fields in the payout flow now specify they refer to the recipient, not the sender. ([#2052](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2052))
- **Sell flow null error fixed**: Resolved a crash in the sell flow caused by a null reference. ([#2113](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2113))
- **Order API reliability**: Added timeout and null safety to order API calls to prevent hangs. ([#2099](https://github.com/SatoshiPortal/bullbitcoin-mobile/pull/2099))

### Bug Fixes

#### Sending & Receiving
- Cold wallet selection no longer silently reverts to the hot wallet when entering an amount. ([#1918](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1918))
- Fixed "Build failed (amount mismatch)" error when sending max balance via on-chain swap (L-BTC to BTC). ([#1735](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1735))
- On-chain receive now correctly uses the exact amount you requested. ([#1832](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1832))
- Expired Lightning invoices are detected and rejected before you attempt to pay.
- Failed broadcasts now show clear error messages with pinned action buttons.
- Importing an already-existing mnemonic now warns you instead of silently replacing the default wallet. ([#1783](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1783))
- Removed "adjustment" from transaction filters. ([#1960](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1960))

#### Swaps
- Changing the source wallet in a swap now correctly switches the destination wallet. ([#1939](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1939))
- Autoswap active indicator now appears correctly on the home screen. ([#2196](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2196))

#### QR Codes & Hardware Wallets
- PSBT QR codes are now readable by Jade hardware wallets in dark mode. ([#1917](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1917))
- Lightning invoice QR codes are now uppercase for better scanner compatibility. ([#2049](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2049))

#### UI & Layout
- Send and Receive buttons stay visible at the bottom of home and wallet screens. ([#2143](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2143), [#2191](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2191))
- Fixed dark text on dark background across multiple screens. ([#1931](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1931), [#2053](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2053), [#1965](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1965))
- Payjoin status in the list now matches the detail view. ([#2135](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2135))
- Fixed startup screen button error and grammar. ([#2116](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2116))

#### Translations
- Spanish: filled missing translations across multiple screens. ([#2051](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2051))
- Simplified Chinese: improved wallet, payment, onboarding, backup, and deletion screens.
- German: updated throughout.
- Hinglish: now correctly resolves to hi_Latn.

---

## [6.10.6] - 2026-05-18

### Bug Fixes

- **iOS background tasks now actually execute**: Registered Flutter plugins in the workmanager background isolate via `WorkmanagerPlugin.setPluginRegistrantCallback`. Without this, every iOS background fire (`bitcoin-sync`, `liquid-sync`, `swaps-sync`, `logs-prune`) crashed at plugin init with `Unable to establish connection on channel: dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi.getAll` because the background `FlutterEngine` started with an empty plugin registry. Periodic syncs now run for the first time.
- **No more "App Init Error -25308" on iOS**: Closed every pre-first-unlock keychain-read surface on iOS startup. The legacy Hive box opens lazily — the keychain read for its encryption key now fires only when a v4/v5 migration path actually needs old data, instead of eagerly during DI bootstrap; previously, every iOS pre-warmed app spawn (which runs `application:didFinishLaunchingWithOptions:` before the user has unlocked the device since boot) crashed app init with `errSecInteractionNotAllowed`. The Future cache self-clears on failure so a later post-unlock attempt succeeds. iOS additionally short-circuits three legacy paths entirely on platforms that never shipped them: the Hive datasource, the fss9/fss10 hybrid probe in `StorageLocator` (Android-only — ESP is `androidx.security.crypto`), and the legacy version-marker check in `RequiresMigrationUsecase`. Android is the only platform that ever shipped a v0.1–v0.4 BULL build, so no install on iOS/macOS/web/Linux/Windows can hold a legacy version marker or Hive data and the eager keychain reads were dead work.
- **Keychain-locked state no longer conflated with "seed missing"**: The iOS keychain error `-25308 / errSecInteractionNotAllowed` is now mapped to a typed `KeychainLockedException` at the secure-storage datasource layer (both fss10 and the legacy fss9 paths). The seed datasource explicitly rethrows it before its `SeedNotFoundException` fallback, preventing a transient pre-unlock failure from being mistaken for a missing wallet seed and triggering destructive recovery flows downstream.
- **No more "App Startup Error" / "Contact support" screen on iOS pre-warm**: `AppStartupBloc` now catches `KeychainLockedException` specifically and stays in the loading state (splash screen) instead of emitting `AppStartupState.failure`. The bloc registers as a `WidgetsBindingObserver` and re-dispatches `AppStartupStarted` on `AppLifecycleState.resumed` — which only fires after the user has unlocked the device since boot. Result: a pre-warmed app that hit the locked keychain at boot transitions cleanly to the success state the first time the user opens the app, instead of leaving them stuck on the error screen.
- **Logs no longer interleave between foreground and background isolates**: Main and workmanager isolates now write to separate files (`bull_logs.tsv` and `bull_background_logs.tsv`). When iOS spawns the app process to fire a periodic task, both engines can be alive simultaneously inside the same process; previously their concurrent writes to a single TSV file tore log lines mid-string. The log viewer and share/export paths merge both files by timestamp on read, so the user-visible behavior is unchanged. Additional flush points were added around the foreground crash zone-guard, the BG isolate's task return path, and `inactive`/`hidden`/`paused` lifecycle transitions so log lines reach disk before any abrupt teardown. Each isolate prunes its own file (cross-isolate prune was rejected to avoid `writeAsString`-vs-`IOSink.flush` races that would destroy the most recently buffered BG lines).
- **`Unknown Background Task` on iOS BG fire**: `BackgroundTask.fromName` now accepts both the Android short name (e.g. `logs-prune`) and the iOS BGTaskScheduler identifier (e.g. `com.bullbitcoin.mobile.logs-prune-id`). `workmanager_apple` forwards the full reverse-DNS identifier while `workmanager_android` forwards the short task name, an asymmetry that previously aborted iOS BG dispatch on the first fire.
- **SQLite "database is locked (code 261)" on BG isolate startup**: Set `PRAGMA busy_timeout` BEFORE `PRAGMA journal_mode = WAL` in both the main-isolate and BG-spawned drift connection setups. The busy handler is connection-scoped (see `sqlite3_busy_timeout`); installing it second meant the WAL-mode flip itself had no retry window and returned `SQLITE_BUSY_RECOVERY` (extended errno 261) when the other isolate held the file at open time. The 2000ms timeout itself is unchanged — only the ordering was wrong.

---

## [6.10.1] - 2026-05-17

### New Features

#### Wallet & Storage
- **FSS hybrid storage strategy** — Flutter secure storage hybrid strategy without migration; better handling of FSS10 migration failure on Android with fallback to legacy storage. Switched to a fork of `flutter_secure_storage` (10.0.0) that improves Android migration reliability by creating backups before migrating secure storage, and improves iOS background task access.
- **New onboarding/startup wizard**
- **Ledger hardware wallet support** — now accessible without requiring superuser privileges
- **Electrum timeout and retry** via bdk-dart
- **Increased Electrum stopGap** — now allows values up to 5000

#### Exchange
- **Colombia (COP) deposits** — new COP payment link deposit flow
- **SINPE receipt on tx details** — reusable card on success + details screens
- **Enhanced exchange settings menu** — new functional screens: Recipients, Transactions, Default Bitcoin Wallets, App Settings, Secure File Upload, Statistics
- **Transaction filters** — added missing order type filters (Withdraw, Pay, Funding, Reward, Refund, Balance Adjustment) to exchange transactions page
- **Email notifications toggle** — enable/disable email notifications in App Settings
- **Secure file upload** — KYC document upload screen with status indicators (Upload, In Review, Accepted)
- **Trading statistics dashboard** — buy/sell ratio, trade volumes, trade counts, average prices, and biller statistics
- **Preferred currency improvements** — exchange home handles empty balance currency; deposit/withdraw/pay screens default to preferred currency
- **Announcement banner improvements** — truncated descriptions with ellipsis; tap to open full details in a bottom sheet
- **Scam consent warning** — explicit consent required before funding exchange account

#### Real-time & Notifications
- **Real-time WebSocket notifications** — balance, KYC status, and group membership updates arrive instantly instead of polling every 5 seconds
- **Real-time support chat** — support messages appear immediately via WebSocket push

#### UX
- **Pull-to-refresh on wallet home** — can be triggered from anywhere on the screen
- **Backup warning overlay** — bottom sheet hard escalation warning for backup when wallet has funds and no backup is detected
- **Close button on broadcasting screen** — added since the app no longer auto-progresses when autosync is disabled

#### Privacy & Payjoin
- **Randomized OHTTP relay selection** — relay randomly selected per payjoin call via `Random.secure()` to prevent network fingerprinting
- **Payjoin self-transfer detection** — detects self-spent transactions and shows a "Self-transfer" row on confirmation; self-spends bypass payjoin

#### Internationalization
- **11 new languages** — Arabic, Bulgarian, Bengali, Czech, Greek, Persian, Hindi, Korean, Brazilian Portuguese, Thai, Turkish
- **Detailed German translations** — community contributions from @bsn21m
- **Updated translations** for new warning and wizard pages

#### Observability
- **Opt-in error reporting** — optional, self-hosted Sentry (disabled by default) — only collects error reports and stack traces, no telemetry, no IP.
- **Detailed Sentry configuration** to ensure user privacy
- **No app restart required** after providing Sentry consent

#### Removed / Changed
- Removed Boltz testnet support
- Removed Recoverbull sync page
- Server status page now makes more realistic calls

### Bug Fixes

#### Wallet Core
- **Address index issue** — fixed via update to bdk-dart (bdk 2.0)
- **Crash for unknown script transactions**
- **Prevent duplicate mnemonic import**
- **Mnemonic import freeze/crash**
- **Capital letters in mnemonic** — no longer accepted (was causing errors)
- **Correct Testnet electrum URLs**
- **LWK database initialization** — fixed Liquid wallet database init issues
- **Spam create wallet on startup**
- **Startup lag** — fixed lag during wallet and seed loading on startup
- **Startup error screen** — gracefully handles and displays startup failures instead of freezing
- **Always ensure both instant and secure wallet are created** — should be atomic
- **Seed fetch retry logic** — added retry mechanism with exponential backoff (up to 5 attempts) when fetching seeds from secure storage to prevent false "Seed Not Found" errors during app startup

#### Swaps
- **Swap status recovery** — added automatic outspend checks for swaps stuck with 'missing-or-unspent' errors during claim/refund broadcast to correctly update swap status
- **Swap watcher race condition** that could cause status update issues
- **MRH swap** — uses transaction ID to fully resolve as a swap transaction
- **Swap flow wallet autoselect** — prevents self-spends or same-network sends in the transfer flow
- **Amountless invoice handling** — throws a more descriptive error for amountless invoices on swaps
- **Background tasks cleanup** — removed unnecessary background tasks causing unexpected swap states and LWK db corruption
- **Autoswap update fix** — fixed issues from previous autoswap implementation
- **Autoswap notice/warning fixes**
- **Testnet fix for recoverbull**

#### Send / Receive
- **LN receive success screen crash** fixed
- **Insufficient balance navigation** — Continue on send amount page with insufficient funds no longer navigates to confirm page
- **Sell/Pay flow** — fixed "Could not fetch fees" bug
- **Route unauthenticated users to login** via buy/sell/withdraw

#### Backup & Security
- **Physical backup verification** — fixed backup test status not updating after completing verification
- **Backup-before-PIN safety gate**
- **Backup completion flow via FSS Warning** — after completing a backup, the warning lands directly on the "Reinstall" title instead of flashing "Backup and Reinstall"
- **Backup wallet warning on home** now updates correctly after a backup is complete
- **"Vault created successfully" snackbar** no longer covers the "Test Recovery" button

#### Exchange
- **Exchange statistics** — linear progress indicators, integer trade counts, currency conversion, thousands separators
- **CA KYC sell limit** — enforced $999 CAD buy/sell limit for Canadian users with limited KYC
- **Argentina recipients**
- **Routing to support via "Get Help"**
- **Support chat attachments** — improved image picker with better permission handling and clearer errors
- **WebSocket reconnect loop** — fixed infinite reconnect loop for unauthenticated users
- **Exchange login screen** — minor UI enhancements to exchange login screen and bottom navigation bar

#### Pricing & DCA
- **Price graph refresh** — users can now manually reload Bitcoin prices if automatic loading fails
- **DCA confirmation text color** in dark mode
- **DCA UI fixes**

#### Labels & Persistence
- **Labels feature refactor** — complete architecture refactor with database migration v11→v12; fixed upsert constraint failures, SQLite concurrency, and multiple related issues
- **Transaction note persistence**
- **SQLite migration safety** — catch blocks around label migration to prevent crash on failure

#### Network / Connectivity
- **Custom mempool server** — SSL toggle (auto-detected from URL), improved URL parsing/normalization, server status indicators, dark mode fixes, and hidden service support via Orbot
- **Recoverbull Orbot detection** — checks if Orbot is actually running on port 9050 instead of relying on user settings, preventing Tor-over-Tor errors

#### Input & Keyboard
- **iOS price input keyboard** — fixed to show correct number pad with decimal settings
- **Keyboard lag** — fixed lag when importing mnemonic passphrase or typing in label input fields

#### Theming
- **Dark theme fixes** — QR code backgrounds, PSBT flow, exchange logout sheet, Recoverbull button, custom Electrum server widget, exchange home KYC status card
- **PIN light theme readability**
- **Custom fee dark mode**
- **Light mode exchange banner**
- **Delete logs** dark mode fix
- **Swap fees** dark/light mode and text color fixes
- **Storage warning screens** dark mode background now matches the wizard
- **Fade-to-background gradient** no longer covers the title/description above the button
- **Pull to sync** loader no longer lands behind the Bull logo

#### Wizard / Onboarding Polish
- Removed translation bottom warning sheet in wizard
- Replaced next button with inline YES / NO continue button in the wizard (reporting program)
- Transparent chrome so small screens can see there is more to scroll

#### iOS
- **iOS Sentry fix** — fixed missing Sentry CocoaPod dependency that prevented error reports from being captured on iOS

### Dependencies
- **Updated dependencies** — boltz-dart and satoshifier-dart updated to latest versions

---

## Previous Releases

For release history prior to v6.10.1, please refer to the [GitHub Releases](https://github.com/SatoshiPortal/bullbitcoin-mobile/releases) page.
