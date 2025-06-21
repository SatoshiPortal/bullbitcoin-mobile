part of 'wallet_bloc.dart';

sealed class WalletEvent {
  const WalletEvent();
}

class WalletStarted extends WalletEvent {
  const WalletStarted();
}

class WalletRefreshed extends WalletEvent {
  const WalletRefreshed();
}

class WalletSyncStarted extends WalletEvent {
  final Wallet wallet;

  const WalletSyncStarted(this.wallet);
}

class WalletSyncFinished extends WalletEvent {
  final Wallet wallet;

  const WalletSyncFinished(this.wallet);
}

class StartTorInitialization extends WalletEvent {
  const StartTorInitialization();
}

class CheckAllWarnings extends WalletEvent {
  const CheckAllWarnings();
}

class ExecuteAutoSwap extends WalletEvent {
  final Wallet liquidWallet;

  const ExecuteAutoSwap(this.liquidWallet);
}
