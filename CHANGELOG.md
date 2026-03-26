# Changelog

All notable changes to Bull Bitcoin Mobile will be documented in this file.

## [X.X.X] - To be released

### Bug Fixes
- **Transaction note now saved to database** ([#1173](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1173)): Fixed an issue where notes added during a send were stored in state but never persisted. Notes embedded in Bolt11 invoice descriptions or BIP21 label parameters are also automatically pre-populated if the user has not set one manually

---

## [6.8.0] - 2026-03-17

### New Features

#### Exchange
- **Real-time WebSocket notifications**: Exchange updates (balance, KYC status, group membership) now arrive instantly via WebSocket instead of polling every 5 seconds, providing faster feedback and reducing battery drain
- **Real-time support chat**: Support messages now appear immediately without manual refresh via WebSocket push notifications
- **Enhanced exchange settings menu**: Added new functional screens including Recipients, Transactions, Default Bitcoin Wallets, App Settings, Secure File Upload, and Statistics
- **Bitcoin wallets management**: New screen to manage default Bitcoin, Lightning, and Liquid withdrawal addresses with edit/save/delete functionality
- **Email notifications toggle**: Added option in App Settings to enable/disable email notifications
- **Secure file upload**: New KYC document upload screen with status indicators (Upload, In Review, Accepted)
- **Trading statistics dashboard**: New Statistics screen showing buy/sell ratio, trade volumes, trade counts, average prices, and biller statistics
- **Transaction filters**: Added missing order type filters (Withdraw, Pay, Funding, Reward, Refund, Balance Adjustment) to exchange transactions page
- **Exchange announcement banner improvements**: Announcements now show truncated descriptions with ellipsis, and tapping opens a bottom sheet with full details
- **Preferred currency improvements**: Exchange home now properly handles empty balance currency, and deposit/withdraw/pay screens set initial dropdown values to preferred currency jurisdiction

#### Security & Privacy
- **Backup warning overlay**: Users are now shown a persistent overlay warning when their wallet backup is incomplete, preventing them from dismissing it by navigating away without addressing it.
- **Scam consent warning for exchange funding**: Users must explicitly consent to a scam warning before funding their exchange account, protecting against social engineering attacks
- **Randomized OHTTP relay selection**: OHTTP relay is now randomly selected on each payjoin call using `Random.secure()` to prevent network-layer fingerprinting

#### Payjoin
- **Self-transfer detection**: Payjoin send now detects self-spent transactions and displays a "Self-transfer" row on the confirmation screen. Self-spends bypass payjoin.
- **Close button on broadcasting screen**: Added a Close button on the broadcasting/loading screen since the app no longer auto-progresses when autosync is disabled

#### Localization
- **11 new languages exposed in the language selector**: 🇸🇦 Arabic, 🇧🇬 Bulgarian, 🇧🇩 Bengali, 🇨🇿 Czech, 🇬🇷 Greek, 🇮🇷 Persian, 🇮🇳 Hindi, 🇰🇷 Korean, 🇧🇷 Brazilian Portuguese, 🇹🇭 Thai, 🇹🇷 Turkish

#### Error Reporting
- **Opt-in error reporting program**: Added optional, self-hosted error reporting (disabled by default) with explicit user consent toggle in App Settings. Only collects error reports and stack traces, no user behavior tracking or telemetry

#### Hardware Wallets
- **Ledger available without superuser**: Ledger hardware wallet integration is now accessible without requiring superuser privileges

### Bug Fixes

#### Swap & Lightning
- **Swap status recovery**: Added automatic outspend checks for swaps stuck with 'missing-or-unspent' errors during claim/refund broadcast to correctly update swap status
- **Swap watcher race condition**: Fixed race condition in swap watcher that could cause status update issues
- **Price graph refresh**: Users can now manually reload Bitcoin prices if automatic loading fails
- **LN receive success screen crash**: Fixed a UI crash that occurred when reaching the success screen after receiving via Lightning through the wallet receive pages
- **Insufficient balance navigation**: Improved error on insufficient balance and swap limits. Fixed an issue where clicking Continue on the send amount page with insufficient funds would show an error but still navigate to the confirm page
- **Handle amountless invoice**: Better handling of amountless invoices on swaps. Throws a more descriptive error.

#### Exchange
- **WebSocket reconnect loop**: Fixed infinite reconnect loop where unauthenticated users would see repeated WebSocket connection errors every 5 seconds
- **Exchange statistics improvements**: Replaced circular progress indicators with linear ones, fixed trade count display to show plain integers, added currency conversion for statistics, and improved number formatting with thousands separators
- **DCA confirmation text color**: Fixed unreadable text color on DCA confirmation screen by using proper theme color
- **Support chat attachments**: Improved image picker flow with better permission handling and clearer error messages
- **CA KYC Limited sell limit**: Enforced the $999 CAD buy/sell limit for Canadian users with limited KYC verification, with proper form validation

#### Wallet & Transactions
- **Labels feature refactor**: Complete refactor of labels architecture with database migration (v11 to v12), improved domain modeling, and better separation of concerns. Fixed multiple label-related issues
- **Physical backup verification**: Fixed issue where physical backup test status was not updating after completing verification
- **Custom fee theme**: Fixed theme color issues in custom fee selection
- **Keyboard input improvements**: Fixed price input keyboard to show appropriate number pad on iOS with correct decimal settings
- **Keyboard lag fix**: Fixed keyboard lag when importing a mnemonic passphrase or typing in label input fields

#### Mempool & Network
- **Custom mempool server fixes**: Added SSL toggle (auto-detected from URL protocol), improved URL parsing and normalization, added server status indicators, fixed UI issues in dark mode, and added support for .onion links via Orbot
- **Recoverbull Orbot detection**: Fixed Recoverbull connection by checking if Orbot is actually running on port 9050 instead of just checking user settings, preventing Tor-over-Tor connection errors

#### UI & Theme
- **Multiple dark theme fixes**: Fixed various dark theme issues including QR code backgrounds (now hardcoded white for hardware wallet compatibility), PSBT flow instructions visibility, exchange logout bottom sheet theme, and Recoverbull button theme; also fixed custom Electrum server delete widget, "how to decide" bottom sheet, and exchange home KYC card
- **DCA UI fixes**: Fixed theme color issues in DCA screens
- **Light mode exchange banner**: Fixed banner color rendering in light mode
- **Exchange login screen**: Minor UI enhancements to the exchange login screen and bottom navigation bar

#### Performance & Stability
- **Startup lag fix**: Fixed lag on startup during wallet and seed loading.
- **LWK database fixes**: Fixed Liquid wallet database initialization issues
- **SQLite migration safety**: Added catch blocks around SQLite migration for labels to prevent crash on migration failure
- **Startup error screen**: Added an error screen in main to gracefully handle and display startup failures instead of freezing
- **Background tasks**: Removed unnecessary background tasks (only log pruning remains) which were leading to unexpected behaviour and bad states on swaps in particular.

#### Reliability & Stability
- **Secure storage updates**: Updated to Flutter Secure Storage 10.0.0 with improved iOS background task access and better Android compatibility. Should fix app startup issues
- **Seed fetch retry logic**: Added retry mechanism with exponential backoff (up to 5 attempts) when fetching seeds from secure storage to prevent false "Seed Not Found" errors during app startup
- **Autoswap update fix**: Fixed issues from previous autoswap implementation

#### Error Reporting
- **iOS Sentry fix**: Fixed missing Sentry CocoaPod dependency that prevented error reports from being captured on iOS

### Dependencies
- **Flutter Secure Storage**: Switched to a fork of `flutter_secure_storage` that improves Android migration reliability by creating backups before migrating secure storage, preventing data loss during upgrades
- **Updated dependencies**: Updated boltz-dart and satoshifier-dart to latest versions

### Breaking Changes
- **Labels database migration**: The labels feature has undergone a database schema migration from v11 to v12. Existing labels will be preserved during the migration

---

## Previous Releases

For release history prior to v6.8.0, please refer to the [GitHub Releases](https://github.com/SatoshiPortal/bullbitcoin-mobile/releases) page.
