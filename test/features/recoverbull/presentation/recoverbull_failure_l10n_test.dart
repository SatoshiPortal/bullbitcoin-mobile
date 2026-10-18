import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/recoverbull/presentation/recoverbull_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _translate(
  WidgetTester tester,
  RecoverBullFailure failure,
) async {
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
  // The production key server locks an identifier for a day.
  testWidgets('a lockout of hours reads in hours and minutes', (tester) async {
    final message = await _translate(
      tester,
      const VaultRateLimitedFailure(
        retryIn: Duration(hours: 23, minutes: 18, seconds: 40),
      ),
    );

    expect(message, 'Rate limited. Please try again in 23 h 18 min');
  });

  testWidgets('a lockout under an hour still reads in minutes', (tester) async {
    final message = await _translate(
      tester,
      const VaultRateLimitedFailure(retryIn: Duration(minutes: 5)),
    );

    expect(message, 'Rate limited. Please try again in 5 minutes');
  });
}
