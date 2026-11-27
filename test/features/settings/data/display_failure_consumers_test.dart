import 'package:overview/overview.dart' show OverviewAmountDisplay;
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Reader implements AmountDisplayPreferencesReader {
  @override
  Stream<Result<AmountDisplayPreferences, PreferencesFailure>>
  watchDisplayPreferences() => Stream.fromIterable([
    const Ok((
      bitcoinUnit: BitcoinUnit.sats,
      hideAmounts: false,
      currencyCode: 'USD',
    )),
    const Err(PreferencesReadFailure()),
    const Ok((
      bitcoinUnit: BitcoinUnit.btc,
      hideAmounts: true,
      currencyCode: 'CAD',
    )),
  ]);
}

void main() {
  final reader = _Reader();
  final consumers = {'overview': OverviewAmountDisplay(reader).watch};
  for (final consumer in consumers.entries) {
    test(
      '${consumer.key} masks after failure and accepts the recovered preference',
      () async {
        await expectLater(
          consumer.value(),
          emitsInOrder([
            (
              bitcoinUnit: BitcoinUnit.sats,
              hideAmounts: false,
              currencyCode: 'USD',
            ),
            null,
            (
              bitcoinUnit: BitcoinUnit.btc,
              hideAmounts: true,
              currencyCode: 'CAD',
            ),
            emitsDone,
          ]),
        );
      },
    );
  }
}
