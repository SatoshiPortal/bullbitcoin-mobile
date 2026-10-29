sealed class NotificationDestination {
  const NotificationDestination();
  static const walletHome = WalletHomeNotificationDestination();

  /// Only an opaque, locally resolved wallet topic belongs in a payload.
  factory NotificationDestination.wallet(String walletKey) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(walletKey)) {
      throw ArgumentError('Invalid wallet notification key');
    }
    return WalletNotificationDestination._(walletKey);
  }

  String get wireValue;
  static NotificationDestination? fromWire(String value) =>
      value == 'wallet_home' ? walletHome : null;
}

final class WalletHomeNotificationDestination extends NotificationDestination {
  const WalletHomeNotificationDestination();
  @override
  String get wireValue => 'wallet_home';
}

final class WalletNotificationDestination extends NotificationDestination {
  final String walletKey;
  const WalletNotificationDestination._(this.walletKey);
  @override
  String get wireValue => 'wallet';
  @override
  bool operator ==(Object other) =>
      other is WalletNotificationDestination && walletKey == other.walletKey;
  @override
  int get hashCode => walletKey.hashCode;
}
