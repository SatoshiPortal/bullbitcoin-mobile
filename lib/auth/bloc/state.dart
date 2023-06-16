import 'package:bb_mobile/_pkg/extensions.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

enum SecurityStep {
  createPin,
  confirmPin,
  enterPin,
}

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    @Default(SecurityStep.enterPin) SecurityStep step,
    @Default('') String pin,
    @Default('') String confirmPin,
    @Default(true) bool checking,
    @Default('') String err,
    @Default(false) bool fromSettings,
    @Default(false) bool loggedIn,
    @Default(true) bool onStartChecking,
  }) = _AuthState;
  const AuthState._();

  String titleText() {
    if (!fromSettings)
      switch (step) {
        case SecurityStep.createPin:
          return 'auth.steps.create'.translate;
        case SecurityStep.confirmPin:
          return 'auth.steps.confirm'.translate;
        case SecurityStep.enterPin:
          return 'auth.steps.enter'.translate;
      }

    if (fromSettings)
      switch (step) {
        case SecurityStep.enterPin:
          return 'auth.steps.enter'.translate;

        case SecurityStep.createPin:
          return 'auth.steps.createnew'.translate;

        case SecurityStep.confirmPin:
          return 'auth.steps.confirmnew'.translate;
      }

    return '';
  }

  bool showButton() {
    if (step == SecurityStep.enterPin || step == SecurityStep.createPin) {
      if (pin.isNotEmpty && pin.length >= 4) return true;
    }

    if (step == SecurityStep.confirmPin) {
      if (confirmPin.isNotEmpty && pin.length >= 4) return true;
    }

    return false;
  }

  String displayPin() {
    var text = '';
    if (step == SecurityStep.enterPin || step == SecurityStep.createPin)
      text = pin;
    else
      text = confirmPin;

    return 'x' * text.length;
  }
}
