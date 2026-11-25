import 'package:preferences/preferences.dart'
    show PaymentAnimationPreferencesReader;

/// Whether the receive flow plays its payment transition. Animations stay on
/// when the preference cannot be read.
class ReadReceivePaymentAnimationsUsecase {
  final PaymentAnimationPreferencesReader _preferences;

  const ReadReceivePaymentAnimationsUsecase(this._preferences);

  Future<bool> execute() async =>
      (await _preferences.readShowPaymentAnimations()).fold(
        (enabled) => enabled,
        (_) => true,
      );
}
