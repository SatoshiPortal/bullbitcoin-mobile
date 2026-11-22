part of 'pin_code_setting_bloc.dart';

sealed class PinCodeSettingEvent {
  const PinCodeSettingEvent();
}

class PinCodeSettingInitialized extends PinCodeSettingEvent {
  const PinCodeSettingInitialized();
}

class PinCodeSettingStarted extends PinCodeSettingEvent {
  const PinCodeSettingStarted();
}

class PinCodeSettingPinCodeNumberAdded extends PinCodeSettingEvent {
  final int number;

  const PinCodeSettingPinCodeNumberAdded(this.number);
}

class PinCodeSettingPinCodeNumberRemoved extends PinCodeSettingEvent {
  const PinCodeSettingPinCodeNumberRemoved();
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
