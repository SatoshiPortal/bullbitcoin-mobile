import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/presentation/sell_failure_l10n.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// A raw reason of the shape the API and BDK/LWK actually produce. Every
/// variant below carries it so the assertions can prove it never survives into
/// the translated string — the `unexpected` arm used to return it verbatim.
const _rawReason =
    'PrepareBitcoinSendException: insufficient funds for address '
    'bc1qsecret, xprv9s21ZrQH143K3';

final _everyFailure = <SellFailure>[
  const SellPayjoinPausedFailure(),
  const SellUnauthenticatedFailure(_rawReason),
  const SellBelowMinAmountFailure(
    minAmount: 10,
    currency: 'CAD',
    logMessage: _rawReason,
  ),
  const SellAboveMaxAmountFailure(
    maxAmount: 5000,
    currency: 'CAD',
    logMessage: _rawReason,
  ),
  const SellOrderNotFoundFailure(_rawReason),
  const SellOrderAlreadyConfirmedFailure(_rawReason),
  const SellDepositAddressChangedFailure(_rawReason),
  const SellInsufficientBalanceFailure(
    requiredAmountSat: 100000,
    logMessage: _rawReason,
  ),
  const SellFeeBelowRelayFloorFailure(_rawReason),
  const SellFeesUnavailableFailure(_rawReason),
  const SellQuoteExpiredFailure(_rawReason),
  const SellQuoteUnavailableFailure(_rawReason),
  const SellUnexpectedFailure(_rawReason),
];

Future<String> _translate(
  WidgetTester tester,
  SellFailure failure, {
  Locale? locale,
}) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          message = failure.toTranslated(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return message;
}

void main() {
  group('SellFailureL10n.toTranslated', () {
    for (final failure in _everyFailure) {
      testWidgets('${failure.runtimeType} resolves to a user-safe message', (
        tester,
      ) async {
        final message = await _translate(tester, failure);

        expect(
          message,
          isNotEmpty,
          reason: 'the .arb key for ${failure.runtimeType} resolved to nothing',
        );
        // #1895: the raw reason is for logs and Sentry only.
        expect(message, isNot(contains(_rawReason)));
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('xprv')));
        expect(message, isNot(contains('bc1q')));
      });
    }

    // The regression this whole migration exists for: `unexpected` used to be
    // `(message) => message`, handing BDK/LWK/API text straight to the screen.
    testWidgets('the catch-all never echoes its own reason', (tester) async {
      final withReason = await _translate(
        tester,
        const SellUnexpectedFailure('Failed to place sell order: $_rawReason'),
      );
      final withoutReason = await _translate(
        tester,
        const SellUnexpectedFailure(),
      );

      expect(
        withReason,
        withoutReason,
        reason: 'the message must not depend on the raw reason at all',
      );
    });

    testWidgets('a busy wallet is told to retry, not to await a payment', (
      tester,
    ) async {
      final busy = await _translate(
        tester,
        const SellSpendBlockedFailure(busy: true),
      );
      final awaiting = await _translate(
        tester,
        const SellSpendBlockedFailure(),
      );

      expect(busy, isNot(awaiting));
      expect(busy, contains('busy'));
    });

    testWidgets('every variant reads differently from the catch-all', (
      tester,
    ) async {
      final generic = await _translate(tester, const SellUnexpectedFailure());

      for (final failure in _everyFailure) {
        if (failure is SellUnexpectedFailure) continue;
        expect(
          await _translate(tester, failure),
          isNot(generic),
          reason: '${failure.runtimeType} is indistinguishable from "oops"',
        );
      }
    });
  });
}
