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
  walletSettings('bitcoin-settings'),
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
