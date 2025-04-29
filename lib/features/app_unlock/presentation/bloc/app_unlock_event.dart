part of 'app_unlock_bloc.dart';

sealed class AppUnlockEvent {
  const AppUnlockEvent();
}

class AppUnlockStarted extends AppUnlockEvent {
  const AppUnlockStarted();
}

class AppUnlockPinCodeNumberAdded extends AppUnlockEvent {
  const AppUnlockPinCodeNumberAdded(this.number);
  final int number;
}

class AppUnlockPinCodeNumberRemoved extends AppUnlockEvent {
  const AppUnlockPinCodeNumberRemoved();
}

class AppUnlockSubmitted extends AppUnlockEvent {
  const AppUnlockSubmitted();
}

class AppUnlockCountdownTick extends AppUnlockEvent {
  const AppUnlockCountdownTick();
}

class AppUnlockPinCodeObscureToggled extends AppUnlockEvent {}
