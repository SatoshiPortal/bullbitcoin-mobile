part of 'home_bloc.dart';

sealed class HomeEvent {
  const HomeEvent();
}

class HomeStarted extends HomeEvent {
  const HomeStarted();
}

class HomeRefreshed extends HomeEvent {
  const HomeRefreshed();
}

class HomeWalletSyncStarted extends HomeEvent {
  final Wallet wallet;

  const HomeWalletSyncStarted(this.wallet);
}

class HomeWalletSyncFinished extends HomeEvent {
  final Wallet wallet;

  const HomeWalletSyncFinished(this.wallet);
}

class StartTorInitialization extends HomeEvent {
  const StartTorInitialization();
}
