enum NotificationDestination {
  walletHome('wallet_home');

  final String wireValue;

  const NotificationDestination(this.wireValue);

  static NotificationDestination? fromWire(String value) => switch (value) {
    'wallet_home' => NotificationDestination.walletHome,
    _ => null,
  };
}
