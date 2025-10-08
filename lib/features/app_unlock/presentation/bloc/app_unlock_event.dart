part of 'app_unlock_bloc.dart';

sealed class AppUnlockEvent {
  const AppUnlockEvent();
}

class AppUnlockStarted extends AppUnlockEvent {
  const AppUnlockStarted();
}

class AppUnlockPinCodeNumberChanged extends AppUnlockEvent {
  const AppUnlockPinCodeNumberChanged(this.pinCode);
  final String pinCode;
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
