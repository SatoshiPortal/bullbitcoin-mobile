part of 'app_startup_bloc.dart';

sealed class AppStartupEvent {
  const AppStartupEvent();
}

final class AppStartupStarted extends AppStartupEvent {
  const AppStartupStarted();
}

final class AppStartupUnlocked extends AppStartupEvent {
  const AppStartupUnlocked();
}
