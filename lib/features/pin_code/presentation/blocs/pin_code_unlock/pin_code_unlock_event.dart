part of 'pin_code_unlock_bloc.dart';

sealed class PinCodeUnlockEvent {
  const PinCodeUnlockEvent();
}

class PinCodeUnlockStarted extends PinCodeUnlockEvent {
  const PinCodeUnlockStarted();
}

class PinCodeUnlockPinChanged extends PinCodeUnlockEvent {
  const PinCodeUnlockPinChanged(this.pinCode);
  final String pinCode;
}

class PinCodeUnlockSubmitted extends PinCodeUnlockEvent {
  const PinCodeUnlockSubmitted();
}
