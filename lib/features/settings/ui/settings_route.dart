enum SettingsRoute {
  settings('/settings'),
  search('search'),
  language('language'),
  backupSettings('backup-settings'),
  walletDetailsSelectedWallet('wallet-details/:walletId'),
  allSeedView('seed-viewer'),
  experimental('experimental-settings'),
  exchangeAccess('exchange-access'),
  quickActions('quick-actions'),
  walletSettings('bitcoin-settings'),
  payjoinSettings('payjoin-settings'),
  payjoinAdvancedSettings('payjoin-advanced-settings'),
  autoswapSettings('autoswap-settings'),
  appSettings('app-settings'),
  permissions('permissions'),
  swapRestore('swap-restore'),
  swapRescue('swap-rescue');

  final String path;

  const SettingsRoute(this.path);
}
