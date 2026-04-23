part of 'app_startup_bloc.dart';

sealed class AppStartupState {
  const AppStartupState();
}

class AppStartupInitial extends AppStartupState {
  const AppStartupInitial();
}

class AppStartupLoadingInProgress extends AppStartupState {
  const AppStartupLoadingInProgress();
}

class AppStartupSuccess extends AppStartupState {
  const AppStartupSuccess({
    this.isPinCodeSet = false,
    this.hasDefaultWallets = false,
  });
  final bool isPinCodeSet;
  final bool hasDefaultWallets;
}

class AppStartupFailure extends AppStartupState {
  const AppStartupFailure(this.e, {this.hasBackup = false});
  final Object? e;
  final bool hasBackup;
}
