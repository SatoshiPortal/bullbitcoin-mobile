import 'package:flutter/foundation.dart';

const walletBackupDefaultServerUrl = String.fromEnvironment(
  'BULL_METADATA_BACKUP_BASE_URL',
  defaultValue: 'https://backup.bull-wallet.com',
);

typedef WalletBackupOriginProvider = Future<Uri> Function();

Uri? parseWalletBackupServerOrigin(
  String value, {
  bool allowInsecureLoopback = !kReleaseMode,
}) {
  final uri = Uri.tryParse(value.trim());
  final loopback =
      uri != null &&
      allowInsecureLoopback &&
      uri.scheme == 'http' &&
      const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && !loopback) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    return null;
  }
  return uri.replace(path: '');
}

Future<Uri> defaultWalletBackupOrigin() async =>
    parseWalletBackupServerOrigin(walletBackupDefaultServerUrl) ??
    (throw StateError('Invalid default backup server origin'));
