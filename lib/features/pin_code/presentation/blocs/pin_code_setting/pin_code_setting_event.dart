part of 'pin_code_setting_bloc.dart';

sealed class PinCodeSettingEvent {
  const PinCodeSettingEvent();
}

class PinCodeSettingUnlocked extends PinCodeSettingEvent {
  const PinCodeSettingUnlocked();
}

class PinCodeSettingPinCodeChanged extends PinCodeSettingEvent {
  final String pinCode;

  const PinCodeSettingPinCodeChanged(
    this.pinCode,
  );
}

class PinCodeSettingPinCodeConfirmationChanged extends PinCodeSettingEvent {
  final String pinCodeConfirmation;

  const PinCodeSettingPinCodeConfirmationChanged(
    this.pinCodeConfirmation,
  );
}

class PinCodeSettingSubmitted extends PinCodeSettingEvent {
  const PinCodeSettingSubmitted();
}
