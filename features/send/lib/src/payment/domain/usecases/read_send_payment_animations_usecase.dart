import 'package:preferences/preferences.dart'
    show PaymentAnimationPreferencesReader;

/// Whether the send flow plays its payment transition. Animations stay on
/// when the preference cannot be read.
class ReadSendPaymentAnimationsUsecase {
  final PaymentAnimationPreferencesReader _preferences;

  const ReadSendPaymentAnimationsUsecase(this._preferences);

  Future<bool> execute() async =>
      (await _preferences.readShowPaymentAnimations()).fold(
        (enabled) => enabled,
        (_) => true,
      );
}
