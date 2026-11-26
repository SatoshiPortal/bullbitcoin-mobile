import 'package:preferences/preferences.dart'
    show PaymentAnimationPreferencesReader;

/// Whether the Buy done page shows its payment rail. Animations stay on when
/// the preference cannot be read.
class ReadBuyPaymentAnimationsUsecase {
  final PaymentAnimationPreferencesReader _preferences;

  const ReadBuyPaymentAnimationsUsecase(this._preferences);

  Future<bool> execute() async =>
      (await _preferences.readShowPaymentAnimations()).fold(
        (enabled) => enabled,
        (_) => true,
      );
}
