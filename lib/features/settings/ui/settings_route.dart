enum SettingsRoute {
  settings('/settings'),
  pinCode('pin-code'),
  language('language'),
  currency('currency'),
  backupSettings('backup-settings'),
  walletDetailsWalletList('wallet-details'),
  walletDetailsSelectedWallet(':walletId'),
  walletOptions(':walletId/options'),
  walletAddresses(':walletId/addresses'),
  logs('logs'),
  allSeedView('seed-viewer'),
  experimental('experimental-settings'),
  exchangeAccount('exchange-account'),
  exchangeSettings('exchange-settings'),
  exchangeAccountInfo('exchange-account-info'),
  exchangeSecurity('exchange-security'),
  exchangeBitcoinWallets('exchange-bitcoin-wallets'),
  exchangeAppSettings('exchange-app-settings'),
  exchangeFileUpload('exchange-file-upload'),
  exchangeStatistics('exchange-statistics'),
  exchangeTransactions('exchange-transactions'),
  exchangeLegacyTransactions('exchange-legacy-transactions'),
  exchangeReferrals('exchange-referrals'),
  exchangeLogout('exchange-logout'),
  bitcoinSettings('bitcoin-settings'),
  payjoinSettings('payjoin-settings'),
  payjoinAdvancedSettings('payjoin-advanced-settings'),
  autoswapSettings('autoswap-settings'),
  appSettings('app-settings'),
  theme('theme'),
  swapRestore('swap-restore'),
  swapRescue('swap-rescue'),
  btcMap('btc-map');

  final String path;

  const SettingsRoute(this.path);
}
