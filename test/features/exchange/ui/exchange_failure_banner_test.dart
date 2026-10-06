import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_failure_banner.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The legacy chain interpolated the raw `'$e'`, so `logMessage` can carry an
/// API key and an account email.
const _rawReason =
    'DioException [bad response]: apiKey bbk_live_7f3a9c2e '
    'rejected for sat@example.com';

Future<InfoCard> _pump(WidgetTester tester, ExchangeFailure failure) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ExchangeFailureBanner(failure: failure)),
    ),
  );
  await tester.pumpAndSettle();

  return tester.widget<InfoCard>(find.byType(InfoCard));
}

void main() {
  testWidgets('a stale-account failure is shown translated', (tester) async {
    final card = await _pump(
      tester,
      const ExchangeAccountUnavailableFailure(_rawReason),
    );

    expect(card.description, 'Unable to load account information');
  });

  testWidgets('a preferences failure is shown translated', (tester) async {
    final card = await _pump(
      tester,
      const ExchangePreferencesSaveFailure(_rawReason),
    );

    expect(
      card.description,
      'Your preferences could not be saved. Please try again.',
    );
  });

  testWidgets('no variant ever paints the raw reason', (tester) async {
    for (final failure in const <ExchangeFailure>[
      ExchangeAccountUnavailableFailure(_rawReason),
      ExchangeNotAuthenticatedFailure(_rawReason),
      ExchangePreferencesSaveFailure(_rawReason),
      ExchangeApiKeyStorageFailure(_rawReason),
      ExchangeUnexpectedFailure(_rawReason),
    ]) {
      final card = await _pump(tester, failure);

      expect(card.description, isNotEmpty);
      expect(card.description, isNot(contains('bbk_live_7f3a9c2e')));
      expect(card.description, isNot(contains('sat@example.com')));
      expect(card.description, isNot(contains('DioException')));
    }
  });

  testWidgets('the retry callback is wired to the card', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExchangeFailureBanner(
            failure: const ExchangeAccountUnavailableFailure(),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InfoCard));
    await tester.pumpAndSettle();

    expect(retried, isTrue);
  });
}
