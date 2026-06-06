# Changelog

All notable changes to Bull Bitcoin Mobile will be documented in this file.

---

## [6.11.0] - 2026-06-06

### New Features

#### Your Transactions
- **Export your transaction history to CSV**: You can now download your transaction history as a CSV file, filtered by a date range — handy for your own records and accounting. The export covers your on-chain, Lightning, swap, and payjoin activity.
- **Clearer transaction and receive details**: The confirmation screen before you broadcast a transaction now shows the full amount and fees, even for transactions signed on a separate device. Addresses and transaction IDs can be tapped to expand and long-pressed to copy, with quick links to a block explorer. When you receive on-chain, the wallet now correctly uses the exact amount you asked for.

#### Payments & Exchange
- **Add a note to a payment**: When you send a payment, you can now add a description so you remember what it was for.
- **More access with light verification**: If you have light or limited identity verification, you can now use the exchange in Canada, Costa Rica, and Argentina. The SEPA bank transfer limit has also been raised from €20,000 to €30,000.

#### Swaps
- **Swap expiry reminder**: When you start a swap, the app now reminds you to finish it within 24 hours so you don't miss the window and trigger an automatic refund.
- **Swaps finish on their own**: The unreliable "retry swap claim" button is gone — the app now retries claiming your swap automatically in the background.

#### Wallet & Display
- **Bitcoin price loading placeholder**: While the home screen is still fetching the Bitcoin price, you now see a loading placeholder instead of a misleading "0".
- **Notifications stay out of your way**: In-app notifications now appear at the top of the screen and can be swiped away in any direction, so they no longer cover the buttons you're trying to tap.
- **Easier number entry on iPhone**: Number keypads now have a "Done" button across the send, receive, buy, sell, swap, fee, and settings screens, so you can dismiss the keyboard easily.

#### Privacy
- **Your custom Electrum server is always respected**: If you've set your own Electrum server, the wallet now always uses it and clearly tells you when it can't connect, instead of quietly falling back to the default servers behind your back.

#### Platform
- **Smaller app download**: The app is noticeably smaller to download and update — roughly 270 MB instead of 340 MB.
- **Android beta tester channel**: Android users can now install a separate "Bull Beta" app, with its own icon and a BETA banner, to try upcoming features without affecting their main wallet.
- **Linux desktop (experimental)**: BULL can now run on Linux desktop computers, including pull-to-refresh with a mouse or trackpad. This is an early preview aimed at testers.

#### Languages
- **New and improved translations**: Added Assamese and improved Hindi, Bengali, and Hinglish. Updated German throughout. Improved Simplified Chinese across the wallet, payment, onboarding, backup, deletion, and import screens. Filled in missing translations so more of the app shows in your chosen language.
- **Suggest translation fixes on GitHub**: If you spot a wording issue, the app now points you to GitHub to propose a fix.

### Bug Fixes

#### Sending & Receiving
- **Your chosen wallet stays chosen**: Selecting your cold wallet to send from no longer silently switches back to your hot wallet once you enter an amount.
- **Send your full balance through a swap**: Fixed an error that prevented sending your entire balance when converting Liquid Bitcoin to on-chain Bitcoin.
- **Expired Lightning invoices are caught early**: If a Lightning invoice has already expired, the app now tells you right away instead of letting you try to pay it.
- **Clear messages when a send fails**: If broadcasting a transaction fails (for example, it was already confirmed, the fee is too low, or the network is unreachable), you now see a clear error instead of the button silently resetting. The action buttons also stay pinned at the bottom of the screen.
- **Smoother transfers**: You can now choose to receive an exact amount when transferring with Liquid, you get clearer messages when your balance is too low, and the Continue button stays disabled until everything is filled in correctly.
- **QR codes scan reliably**: QR codes are now readable by a Jade hardware wallet even in dark mode, and Lightning invoice QR codes are shown in uppercase so scanners read them more reliably.
- **No accidental duplicate wallets**: If you try to import a recovery phrase you've already added, the app now warns you instead of creating a second copy.

#### Exchange & Payouts
- **Better payouts**: SINPE phone numbers are now checked instantly with clearer error messages, recipient ID fields have clearer labels, and referral payouts now show their correct amount instead of 0 sats.
- **More reliable buying, selling, and withdrawals**: Fixed cases where these could show an error or hang, and added a timeout so they fail gracefully instead of getting stuck.
- **Cleaner transaction filters**: Removed the "balance adjustment" option that wasn't useful to filter by.

#### Wallet Sync & Status
- **More reliable refreshing**: Your balances and transactions now refresh more dependably — you see a spinner when the app opens and after actions like sending or swapping, the wallet updates automatically when you return to the home screen, and it no longer wastes data syncing in the background.
- **Autoswap shows as active**: When you turn on autoswap, the home screen now correctly shows that it's active.
- **Consistent payjoin status**: A payjoin transaction's status in the list now matches the status shown on its details screen.
- **Steadier startup**: Fixed startup issues that could cause settings or connections to load incorrectly, and an initialization error that could make some actions fail.

#### Appearance & Layout
- **Send and Receive buttons sit correctly** at the bottom of the home and wallet screens.
- **Dark mode fix**: The "View details" button text is no longer invisible in dark mode while a payment is in progress.
- **Cleaner startup screen**: Removed an error caused by a button tooltip and fixed grammar in the startup error message.

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
