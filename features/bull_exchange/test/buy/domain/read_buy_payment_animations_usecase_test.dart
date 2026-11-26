import 'package:bull_exchange/src/buy/domain/read_buy_payment_animations_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Reader implements PaymentAnimationPreferencesReader {
  final Result<bool, PreferencesFailure> result;

  _Reader(this.result);

  @override
  Future<Result<bool, PreferencesFailure>> readShowPaymentAnimations() async =>
      result;
}

void main() {
  test('returns the stored preference', () async {
    expect(
      await ReadBuyPaymentAnimationsUsecase(_Reader(const Ok(false))).execute(),
      isFalse,
    );
    expect(
      await ReadBuyPaymentAnimationsUsecase(_Reader(const Ok(true))).execute(),
      isTrue,
    );
  });

  test('defaults to on when the preference cannot be read', () async {
    expect(
      await ReadBuyPaymentAnimationsUsecase(
        _Reader(const Err(PreferencesReadFailure('unreadable'))),
      ).execute(),
      isTrue,
    );
  });
}
