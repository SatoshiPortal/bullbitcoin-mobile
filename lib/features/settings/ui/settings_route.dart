enum SettingsRoute {
  settings('/settings'),
  search('search'),
  pinCode('pin-code'),
  language('language'),
  currency('currency'),
  backupSettings('backup-settings'),
  walletDetailsSelectedWallet('wallet-details/:walletId'),
  walletAddresses('wallet-details/:walletId/addresses'),
  allSeedView('seed-viewer'),
  experimental('experimental-settings'),
  exchangeAccount('exchange-account'),
  exchangeSettings('exchange-settings'),
  exchangeSecurity('exchange-security'),
  exchangeTransactions('exchange-transactions'),
  exchangeLegacyTransactions('exchange-legacy-transactions'),
  exchangeReferrals('exchange-referrals'),
  exchangeLogout('exchange-logout'),
  walletSettings('bitcoin-settings'),
  payjoinSettings('payjoin-settings'),
  payjoinAdvancedSettings('payjoin-advanced-settings'),
  autoswapSettings('autoswap-settings'),
  appSettings('app-settings'),
  theme('theme'),
  permissions('permissions'),
  swapRestore('swap-restore'),
  swapRescue('swap-rescue'),
  btcMap('btc-map');

  final String path;

  const SettingsRoute(this.path);
}
