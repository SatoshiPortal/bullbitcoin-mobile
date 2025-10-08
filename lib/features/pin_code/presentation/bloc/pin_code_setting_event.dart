part of 'pin_code_setting_bloc.dart';

sealed class PinCodeSettingEvent {
  const PinCodeSettingEvent();
}

class PinCodeSettingStarted extends PinCodeSettingEvent {
  const PinCodeSettingStarted();
}

class PinCodeSettingPinCodeChanged extends PinCodeSettingEvent {
  final String pinCode;

  const PinCodeSettingPinCodeChanged(this.pinCode);
}

class PinCodeSettingPinCodeChosen extends PinCodeSettingEvent {
  const PinCodeSettingPinCodeChosen();
}

class PinCodeSettingPinCodeConfirmationNumberAdded extends PinCodeSettingEvent {
  final int number;

  const PinCodeSettingPinCodeConfirmationNumberAdded(this.number);
}

class PinCodeSettingPinCodeConfirmationNumberRemoved
    extends PinCodeSettingEvent {
  const PinCodeSettingPinCodeConfirmationNumberRemoved();
}

class PinCodeSettingPinCodeConfirmed extends PinCodeSettingEvent {
  const PinCodeSettingPinCodeConfirmed();
}

class PinCodeSettingPinCodeObscureToggled extends PinCodeSettingEvent {
  const PinCodeSettingPinCodeObscureToggled();
}

class PinCodeCreate extends PinCodeSettingEvent {
  const PinCodeCreate();
}

class PinCodeDelete extends PinCodeSettingEvent {
  const PinCodeDelete();
}
