import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The legacy `BullException` chain interpolates the raw `'$e'`, so this is the
/// kind of string that historically reached `logMessage`.
const _rawReason =
    'GetExchangeUserSummaryException: DioException [bad response]: '
    'apiKey bbk_live_7f3a9c2e rejected for sat@example.com';

const _everyFailure = <ExchangeFailure>[
  ExchangeAccountUnavailableFailure(_rawReason),
  ExchangeNotAuthenticatedFailure(_rawReason),
  ExchangeApiKeyStorageFailure(_rawReason),
  ExchangeSessionClearFailure(_rawReason),
  ExchangePreferencesSaveFailure(_rawReason),
  ExchangeAnnouncementsUnavailableFailure(_rawReason),
  ExchangeNotificationsUnavailableFailure(_rawReason),
  ExchangeAccountDeletionRequestFailure(_rawReason),
  ExchangeUnexpectedFailure(_rawReason),
];

Future<String> _translate(WidgetTester tester, ExchangeFailure failure) async {
  late String translated;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          translated = failure.toTranslated(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  return translated;
}

void main() {
  testWidgets('no variant ever renders the raw reason', (tester) async {
    for (final failure in _everyFailure) {
      final message = await _translate(tester, failure);

      expect(message, isNotEmpty);
      expect(
        message,
        isNot(contains('bbk_live_7f3a9c2e')),
        reason: '${failure.runtimeType} leaked the API key',
      );
      expect(
        message,
        isNot(contains('sat@example.com')),
        reason: '${failure.runtimeType} leaked the account email',
      );
      expect(
        message,
        isNot(contains('DioException')),
        reason: '${failure.runtimeType} leaked an exception class name',
      );
      expect(
        message,
        isNot(contains(_rawReason)),
        reason: '${failure.runtimeType} rendered logMessage verbatim',
      );
    }
  });

  testWidgets('the message never depends on the raw reason', (tester) async {
    expect(
      await _translate(
        tester,
        const ExchangeAccountUnavailableFailure(_rawReason),
      ),
      await _translate(tester, const ExchangeAccountUnavailableFailure()),
    );
  });

  testWidgets('each mapped failure reads differently from the catch-all', (
    tester,
  ) async {
    final generic = await _translate(tester, const ExchangeUnexpectedFailure());

    for (final failure in _everyFailure) {
      if (failure is ExchangeUnexpectedFailure) continue;
      // Infrastructure with no user story: the socket is best-effort and this
      // is never surfaced, so it deliberately shares the generic copy.
      if (failure is ExchangeNotificationsUnavailableFailure) continue;
      expect(
        await _translate(tester, failure),
        isNot(generic),
        reason:
            '${failure.runtimeType} is indistinguishable from the generic '
            'message, so the user learns nothing from it',
      );
    }
  });
}
