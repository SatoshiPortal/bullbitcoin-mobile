import 'package:preferences/preferences.dart'
    show PaymentAnimationPreferencesReader;

/// Whether the transfer flow plays its payment transition. Animations stay on
/// when the preference cannot be read.
class ReadTransferPaymentAnimationsUsecase {
  final PaymentAnimationPreferencesReader _preferences;

  const ReadTransferPaymentAnimationsUsecase(this._preferences);

  Future<bool> execute() async =>
      (await _preferences.readShowPaymentAnimations()).fold(
        (enabled) => enabled,
        (_) => true,
      );
}
