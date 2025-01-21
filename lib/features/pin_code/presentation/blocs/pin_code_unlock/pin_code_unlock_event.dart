part of 'pin_code_unlock_bloc.dart';

sealed class PinCodeUnlockEvent {
  const PinCodeUnlockEvent();
}

class PinCodeUnlockStarted extends PinCodeUnlockEvent {
  const PinCodeUnlockStarted();
}

class PinCodeUnlockNumberAdded extends PinCodeUnlockEvent {
  const PinCodeUnlockNumberAdded(this.number);
  final int number;
}

class PinCodeUnlockNumberRemoved extends PinCodeUnlockEvent {
  const PinCodeUnlockNumberRemoved();
}

class PinCodeUnlockSubmitted extends PinCodeUnlockEvent {
  const PinCodeUnlockSubmitted();
}

class PinCodeUnlockCountdownTick extends PinCodeUnlockEvent {
  const PinCodeUnlockCountdownTick();
}
