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

class HomeWalletSynced extends HomeEvent {
  final String walletId;

  const HomeWalletSynced(this.walletId);
}
