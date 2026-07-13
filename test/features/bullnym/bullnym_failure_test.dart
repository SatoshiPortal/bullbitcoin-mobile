import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/presentation/bullnym_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BullnymFailure', () {
    test('preserves stable metadata without exposing diagnostics', () {
      const failure = BullnymFailure.serverRejectedRequest(
        code: 'DonationPageNotFound',
        logMessage: 'diagnostic-only',
        statusCode: 404,
        retryable: false,
      );

      expect(failure.code, 'DonationPageNotFound');
      expect(failure.statusCode, 404);
      expect(failure.retryable, isFalse);
      expect(failure.toString(), isNot(contains('diagnostic-only')));
    });

    testWidgets('every variant renders sanitized localized copy', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );

      const variants = <BullnymFailure>[
        BullnymFailure.invalidInput('diagnostic-only'),
        BullnymFailure.network(logMessage: 'diagnostic-only'),
        BullnymFailure.timeout(logMessage: 'diagnostic-only'),
        BullnymFailure.serverRejectedRequest(
          code: 'X',
          logMessage: 'diagnostic-only',
          retryable: false,
        ),
        BullnymFailure.serverRejectedRequest(
          code: 'X',
          logMessage: 'diagnostic-only',
          retryable: true,
        ),
        BullnymFailure.unexpectedHttpStatus(statusCode: 500),
        BullnymFailure.emptyResponse(statusCode: 204),
        BullnymFailure.invalidServerResponse(logMessage: 'diagnostic-only'),
        BullnymFailure.signingFailed(),
        BullnymFailure.unexpected('diagnostic-only'),
      ];

      for (final failure in variants) {
        final copy = failure.toTranslated(context);
        expect(copy, isNotEmpty);
        expect(copy, isNot(contains('diagnostic-only')));
      }
    });
  });
}
