import 'package:address_view/address_view.dart';
import 'package:labels/labels.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:receive/receive.dart';
import 'package:flutter_test/flutter_test.dart';

class _Labels extends Mock implements Labels {}

class _Preferences extends Mock implements Preferences {}

void main() {
  test('an unavailable preference snapshot never queries the pricer', () async {
    final preferences = _Preferences();
    when(preferences.fetch).thenAnswer(
      (_) async => const Err(PreferencesReadFailure('database failed')),
    );
    final receive = Receive.open(
      addresses: _ReceiveAddressView(),
      labels: _Labels(),
      preferences: preferences,
      readPrice: ({required network, required currency}) =>
          throw StateError('Single price requested without preferences'),
      readPrices: ({required network}) =>
          throw StateError('Quote set requested without preferences'),
    );

    for (final result in [
      await receive.settings(),
      await receive.convertAmount(),
      await receive.amountQuotes(),
    ]) {
      expect(
        result,
        isA<Err<Object?, ReceiveFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<ReceiveUnexpectedFailure>(),
        ),
      );
    }
  });
}

class _ReceiveAddressView extends Mock implements AddressView {}
