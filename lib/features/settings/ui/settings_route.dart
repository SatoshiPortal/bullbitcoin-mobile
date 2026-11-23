enum SettingsRoute {
  language('language'),
  walletDetailsSelectedWallet('wallet-details/:walletId'),
  experimental('experimental-settings'),
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
