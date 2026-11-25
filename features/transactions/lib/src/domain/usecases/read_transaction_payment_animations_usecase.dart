import 'package:preferences/preferences.dart'
    show PaymentAnimationPreferencesReader;

/// Whether the transaction details open on the payment status. Animations stay
/// on when the preference cannot be read.
class ReadTransactionPaymentAnimationsUsecase {
  final PaymentAnimationPreferencesReader _preferences;

  const ReadTransactionPaymentAnimationsUsecase(this._preferences);

  Future<bool> execute() async =>
      (await _preferences.readShowPaymentAnimations()).fold(
        (enabled) => enabled,
        (_) => true,
      );
}
