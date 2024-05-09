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
    @Default([]) List<int> shuffledNumbers,
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
          return 'Create security pin'.translate;
        case SecurityStep.confirmPin:
          return 'Confirm pin'.translate;
        case SecurityStep.enterPin:
          return 'Enter security pin'.translate;
      }

    if (fromSettings)
      switch (step) {
        case SecurityStep.enterPin:
          return 'Enter security pin'.translate;

        case SecurityStep.createPin:
          return 'Create new pin'.translate;

        case SecurityStep.confirmPin:
          return 'Confirm new pin'.translate;
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

  List<int> generateShuffledNumbers() {
    final numbers = List<int>.generate(10, (i) => i);
    numbers.shuffle();
    return numbers;
  }
}
