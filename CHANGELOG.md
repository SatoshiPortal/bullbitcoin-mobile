# Changelog

All notable changes to Bull Bitcoin Mobile will be documented in this file.

## [6.6.0] - 2026-01-30

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

#### Error Reporting
- **Opt-in error reporting program**: Added optional, self-hosted error reporting (disabled by default) with explicit user consent toggle in App Settings. Only collects error reports and stack traces, no user behavior tracking or telemetry

#### Hardware Wallets
- **Ledger available without superuser**: Ledger hardware wallet integration is now accessible without requiring superuser privileges

### Bug Fixes

#### Swap & Lightning
- **Swap status recovery**: Added automatic outspend checks for swaps stuck with 'missing-or-unspent' errors during claim/refund broadcast to correctly update swap status
- **Swap watcher race condition**: Fixed race condition in swap watcher that could cause status update issues
- **Price graph refresh**: Users can now manually reload Bitcoin prices if automatic loading fails

#### Exchange
- **WebSocket reconnect loop**: Fixed infinite reconnect loop where unauthenticated users would see repeated WebSocket connection errors every 5 seconds
- **Exchange statistics improvements**: Replaced circular progress indicators with linear ones, fixed trade count display to show plain integers, added currency conversion for statistics, and improved number formatting with thousands separators
- **DCA confirmation text color**: Fixed unreadable text color on DCA confirmation screen by using proper theme color
- **Support chat attachments**: Improved image picker flow with better permission handling and clearer error messages

#### Wallet & Transactions
- **Labels feature refactor**: Complete refactor of labels architecture with database migration (v11 to v12), improved domain modeling, and better separation of concerns. Fixed multiple label-related issues
- **Physical backup verification**: Fixed issue where physical backup test status was not updating after completing verification
- **Custom fee theme**: Fixed theme color issues in custom fee selection
- **Keyboard input improvements**: Fixed price input keyboard to show appropriate number pad on iOS with correct decimal settings

#### Mempool & Network
- **Custom mempool server fixes**: Added SSL toggle (auto-detected from URL protocol), improved URL parsing and normalization, added server status indicators, fixed UI issues in dark mode, and added support for .onion links via Orbot
- **Recoverbull Orbot detection**: Fixed Recoverbull connection by checking if Orbot is actually running on port 9050 instead of just checking user settings, preventing Tor-over-Tor connection errors

#### Reliability & Stability
- **Secure storage updates**: Updated to Flutter Secure Storage 10.0.0 with improved iOS background task access and better Android compatibility. Should fix app startup issues
- **Seed fetch retry logic**: Added retry mechanism with exponential backoff (up to 5 attempts) when fetching seeds from secure storage to prevent false "Seed Not Found" errors during app startup
- **Autoswap update fix**: Fixed issues from previous autoswap implementation

#### UI & Theme
- **Multiple dark theme fixes**: Fixed various dark theme issues including QR code backgrounds (now hardcoded white for hardware wallet compatibility), PSBT flow instructions visibility, exchange logout bottom sheet theme, and Recoverbull button theme
- **DCA UI fixes**: Fixed theme color issues in DCA screens

#### Dependencies
- **Updated dependencies**: Updated boltz-dart and satoshifier-dart to latest versions

### Breaking Changes
- **Labels database migration**: The labels feature has undergone a database schema migration from v11 to v12. Existing labels will be preserved during the migration

---

## Previous Releases

For release history prior to v6.6.0, please refer to the [GitHub Releases](https://github.com/SatoshiPortal/bullbitcoin-mobile/releases) page.
