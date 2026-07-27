import 'package:bb_mobile/features/consolidation/domain/consolidation_failure.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [ConsolidationFailureL10n.toTranslated] is the one place a
/// [ConsolidationFailure] is allowed to become user-facing text. The
/// contract under test (rule #11): the end user must never see the raw,
/// developer-only [Failure.logMessage] — every variant must resolve to one
/// of the pre-defined, localized strings, regardless of what internal detail
/// the failure was constructed with.
void main() {
  Future<String> translate(
    WidgetTester tester,
    ConsolidationFailure failure,
  ) async {
    late String result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            result = failure.toTranslated(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return result;
  }

  const secretLogMessage = 'raw internal detail the user must never see';

  group('toTranslated never leaks Failure.logMessage', () {
    testWidgets('ConsolidationRequiredFailure', (tester) async {
      final message = await translate(
        tester,
        const ConsolidationRequiredFailure(secretLogMessage),
      );

      expect(message, isNot(contains(secretLogMessage)));
      expect(message, 'Consolidate the wallet');
    });

    testWidgets('ConsolidationCountUnavailableFailure', (tester) async {
      final message = await translate(
        tester,
        const ConsolidationCountUnavailableFailure(secretLogMessage),
      );

      expect(message, isNot(contains(secretLogMessage)));
      expect(message, 'Oops! Something went wrong');
    });

    testWidgets('ConsolidationBuildFailure', (tester) async {
      final message = await translate(
        tester,
        const ConsolidationBuildFailure(secretLogMessage),
      );

      expect(message, isNot(contains(secretLogMessage)));
      expect(
        message,
        'An unexpected error occurred. Your funds are safe — no '
        'transaction was broadcast. Please try again.',
      );
    });

    testWidgets('ConsolidationUnexpectedFailure', (tester) async {
      final message = await translate(
        tester,
        const ConsolidationUnexpectedFailure(secretLogMessage),
      );

      expect(message, isNot(contains(secretLogMessage)));
      expect(message, 'Oops! Something went wrong');
    });

    testWidgets('ConsolidationSyncFailure', (tester) async {
      final message = await translate(
        tester,
        const ConsolidationSyncFailure(secretLogMessage),
      );

      expect(message, isNot(contains(secretLogMessage)));
      expect(
        message,
        "Couldn't refresh your wallet's data before retrying. Please "
        'check your connection and try again.',
      );
    });
  });

  group('ConsolidationSignFailure / ConsolidationBroadcastFailure: the '
      'succeededTxids-aware message is used instead of the generic one, '
      'and still never leaks logMessage', () {
    testWidgets(
      'sign failure with no prior successes uses the generic message',
      (tester) async {
        final message = await translate(
          tester,
          const ConsolidationSignFailure([], secretLogMessage),
        );

        expect(message, isNot(contains(secretLogMessage)));
        expect(
          message,
          'An unexpected error occurred. Your funds are safe — no '
          'transaction was broadcast. Please try again.',
        );
      },
    );

    testWidgets(
      'sign failure with prior successes reports how many, singular',
      (tester) async {
        final message = await translate(
          tester,
          const ConsolidationSignFailure(['txid1'], secretLogMessage),
        );

        expect(message, isNot(contains(secretLogMessage)));
        expect(message, contains('1 transaction was'));
      },
    );

    testWidgets('sign failure with multiple prior successes reports the count, '
        'plural', (tester) async {
      final message = await translate(
        tester,
        const ConsolidationSignFailure([
          'txid1',
          'txid2',
          'txid3',
        ], secretLogMessage),
      );

      expect(message, isNot(contains(secretLogMessage)));
      expect(message, contains('3 transactions were'));
    });

    testWidgets(
      'broadcast failure with no prior successes uses the generic message',
      (tester) async {
        final message = await translate(
          tester,
          const ConsolidationBroadcastFailure([], secretLogMessage),
        );

        expect(message, isNot(contains(secretLogMessage)));
        expect(
          message,
          'An unexpected error occurred. Your funds are safe — no '
          'transaction was broadcast. Please try again.',
        );
      },
    );

    testWidgets('broadcast failure with prior successes reports how many', (
      tester,
    ) async {
      final message = await translate(
        tester,
        const ConsolidationBroadcastFailure([
          'txid1',
          'txid2',
        ], secretLogMessage),
      );

      expect(message, isNot(contains(secretLogMessage)));
      expect(message, contains('2 transactions were'));
    });
  });
}
