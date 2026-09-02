import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/presentation/buy_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A raw reason of the shape the exchange API actually produces — it quotes a
/// key, so none of it may survive into a user-facing string.
const _rawReason = 'DioException 500 apikey=secret123 BuyOrderException';

final _everyFailure = <BuyFailure>[
  const BuyUnauthenticatedFailure(_rawReason),
  const BuyBelowMinAmountFailure(
    minAmount: 25,
    currency: 'CAD',
    logMessage: _rawReason,
  ),
  const BuyAboveMaxAmountFailure(
    maxAmount: 5000,
    currency: 'CAD',
    logMessage: _rawReason,
  ),
  const BuyUnexpectedFailure(_rawReason),
];

Future<String> _translate(WidgetTester tester, BuyFailure failure) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  group('BuyFailureL10n.toTranslated', () {
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
        expect(message, isNot(contains(_rawReason)));
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('secret123')));
      });
    }

    testWidgets('the catch-all never echoes its own reason', (tester) async {
      final withReason = await _translate(
        tester,
        const BuyUnexpectedFailure(_rawReason),
      );
      final withoutReason = await _translate(
        tester,
        const BuyUnexpectedFailure(),
      );

      expect(
        withReason,
        withoutReason,
        reason: 'the message must not depend on the raw reason at all',
      );
    });

    testWidgets('every variant reads differently from the catch-all', (
      tester,
    ) async {
      final generic = await _translate(tester, const BuyUnexpectedFailure());

      for (final failure in _everyFailure) {
        if (failure is BuyUnexpectedFailure) continue;
        expect(
          await _translate(tester, failure),
          isNot(generic),
          reason: '${failure.runtimeType} is indistinguishable from "oops"',
        );
      }
    });
  });
}
