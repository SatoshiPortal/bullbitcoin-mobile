import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_settings_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape of text the exchange API puts in `logMessage`: an error code, an
/// operator-authored sentence, and a bitcoin address.
const _rawReason =
    'ExchangeApiException[ERR_KYC_403]: recipient bc1qexamplerecipient rejected';

/// Every variant of the sealed family, each carrying the raw reason. If a
/// variant is added without being listed here the l10n switch still forces a
/// compile error, but these assertions are what prove it stays sanitized.
const _everyFailure = <ExchangeSettingsFailure>[
  ExchangeSettingsStatisticsUnavailableFailure(_rawReason),
  ExchangeSettingsDefaultWalletsUnavailableFailure(_rawReason),
  ExchangeSettingsWalletAddressEmptyFailure(_rawReason),
  ExchangeSettingsWalletSaveFailure(_rawReason),
  ExchangeSettingsWalletDeleteFailure(_rawReason),
  ExchangeSettingsAccountUnavailableFailure(_rawReason),
  ExchangeSettingsDocumentAlreadySubmittedFailure(_rawReason),
  ExchangeSettingsDocumentEmptyFailure(_rawReason),
  ExchangeSettingsDocumentTooLargeFailure(_rawReason),
  ExchangeSettingsDocumentTypeNotAllowedFailure(_rawReason),
  ExchangeSettingsDocumentUnreadableFailure(_rawReason),
  ExchangeSettingsDocumentUploadFailure(_rawReason),
  ExchangeSettingsUnexpectedFailure(_rawReason),
];

Future<String> _translate(
  WidgetTester tester,
  ExchangeSettingsFailure failure,
) async {
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
        isNot(contains('ERR_KYC_403')),
        reason: '${failure.runtimeType} leaked the API error code',
      );
      expect(
        message,
        isNot(contains('bc1qexamplerecipient')),
        reason: '${failure.runtimeType} leaked a bitcoin address',
      );
      expect(
        message,
        isNot(contains('Exception')),
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
        const ExchangeSettingsDocumentUploadFailure(_rawReason),
      ),
      await _translate(tester, const ExchangeSettingsDocumentUploadFailure()),
    );
  });

  testWidgets('each mapped failure reads differently from the catch-all', (
    tester,
  ) async {
    final generic = await _translate(
      tester,
      const ExchangeSettingsUnexpectedFailure(),
    );

    for (final failure in _everyFailure) {
      if (failure is ExchangeSettingsUnexpectedFailure) continue;
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
