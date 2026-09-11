import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_error_text.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A raw reason of the shape the funding API produces: the JSON-RPC code, the
/// backend's English sentence and a recipient IBAN.
const _rawReason =
    'getUserPaymentProcessorCode API error [ERR_ORD_CSRCP400]: '
    'Recipient DE89370400440532013000 has no virtual payment option';

Future<void> _pump(WidgetTester tester, FundExchangeFailure failure) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FundExchangeErrorText(failure: failure)),
      ),
    );

void main() {
  testWidgets('renders the headline above the message when one exists', (
    tester,
  ) async {
    await _pump(
      tester,
      const FundExchangeSepaVirtualPaymentInactiveFailure(_rawReason),
    );

    expect(find.text('Virtual Payment Not Activated'), findsOneWidget);
    expect(
      find.text(
        'Please activate the virtual payment option for this SEPA recipient',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders a bare message for a title-less failure', (
    tester,
  ) async {
    await _pump(tester, const FundExchangeUnexpectedFailure(_rawReason));

    expect(find.byType(Column), findsNothing);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('never paints the raw reason', (tester) async {
    for (final failure in <FundExchangeFailure>[
      const FundExchangeSepaVirtualPaymentInactiveFailure(_rawReason),
      const FundExchangeKycIncompleteFailure(_rawReason),
      const FundExchangeCopRequestInvalidFailure(_rawReason),
      const FundExchangeUnexpectedFailure(_rawReason),
    ]) {
      await _pump(tester, failure);

      final painted = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' | ');

      expect(painted, isNot(contains('ERR_')));
      expect(painted, isNot(contains('DE89370400440532013000')));
      expect(painted, isNot(contains('API error')));
      expect(painted, isNotEmpty);
    }
  });
}
