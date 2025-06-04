part of 'wallet_home_bloc.dart';

sealed class WalletHomeEvent {
  const WalletHomeEvent();
}

class WalletHomeStarted extends WalletHomeEvent {
  const WalletHomeStarted();
}

class WalletHomeRefreshed extends WalletHomeEvent {
  const WalletHomeRefreshed();
}

class WalletHomeWalletSyncStarted extends WalletHomeEvent {
  final Wallet wallet;

  const WalletHomeWalletSyncStarted(this.wallet);
}

class WalletHomeWalletSyncFinished extends WalletHomeEvent {
  final Wallet wallet;

  const WalletHomeWalletSyncFinished(this.wallet);
}

class StartTorInitialization extends WalletHomeEvent {
  const StartTorInitialization();
}

class CheckAllWarnings extends WalletHomeEvent {
  const CheckAllWarnings();
}
