import 'package:preferences/preferences.dart'
    show PaymentAnimationPreferencesReader;

/// Whether the Ark flows play their payment transition. Animations stay on
/// when the preference cannot be read.
class ReadArkPaymentAnimationsUsecase {
  final PaymentAnimationPreferencesReader _preferences;

  const ReadArkPaymentAnimationsUsecase(this._preferences);

  Future<bool> execute() async =>
      (await _preferences.readShowPaymentAnimations()).fold(
        (enabled) => enabled,
        (_) => true,
      );
}
