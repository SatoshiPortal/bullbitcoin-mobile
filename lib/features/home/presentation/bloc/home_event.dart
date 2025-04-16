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

class HomeTransactionsSynced extends HomeEvent {
  const HomeTransactionsSynced();
}

class StartTorInitialization extends HomeEvent {
  const StartTorInitialization();
}
