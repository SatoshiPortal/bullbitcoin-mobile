enum SettingsRoute {
  language('language'),
  experimental('experimental-settings'),
  quickActions('quick-actions'),
  walletSettings('bitcoin-settings'),
  payjoinSettings('payjoin-settings'),
  payjoinAdvancedSettings('payjoin-advanced-settings'),
  appSettings('app-settings'),
  permissions('permissions');

  final String path;

  const SettingsRoute(this.path);
}
