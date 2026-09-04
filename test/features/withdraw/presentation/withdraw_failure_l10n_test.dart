import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A raw reason of the shape the exchange API actually produces — it quotes a
/// key, so none of it may survive into a user-facing string.
const _rawReason = 'DioException 500 apikey=secret123 WithdrawOrderException';

final _everyFailure = <WithdrawFailure>[
  const WithdrawUnauthenticatedFailure(_rawReason),
  const WithdrawBelowMinAmountFailure(
    minAmount: 25,
    currency: 'CAD',
    logMessage: _rawReason,
  ),
  const WithdrawAboveMaxAmountFailure(
    maxAmount: 5000,
    currency: 'CAD',
    logMessage: _rawReason,
  ),
  const WithdrawUnexpectedFailure(_rawReason),
];

Future<String> _translate(WidgetTester tester, WithdrawFailure failure) async {
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
  group('WithdrawFailureL10n.toTranslated', () {
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

    testWidgets('every variant has a distinct-enough message', (tester) async {
      final messages = <String>{};
      for (final failure in _everyFailure) {
        messages.add(await _translate(tester, failure));
      }

      // The two amount bounds and the catch-all must not collapse into one
      // string: a user who sent too little needs different advice.
      expect(messages.length, greaterThanOrEqualTo(3));
    });
  });
}
