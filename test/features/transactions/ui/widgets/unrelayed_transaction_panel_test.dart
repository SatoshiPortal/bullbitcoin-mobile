import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/unrelayed_transaction_panel.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, String locale, bool dark) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.themeData(dark ? AppThemeType.dark : AppThemeType.light),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  for (final locale in ['en', 'fr']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$locale dark=$dark manual actions and explicit Cancel consent',
        (tester) async {
          var retries = 0, cancellations = 0;
          await tester.pumpWidget(
            _app(
              UnrelayedTransactionPanel(
                onRetry: () => retries++,
                onCancel: () => cancellations++,
              ),
              locale,
              dark,
            ),
          );
          await tester.pumpAndSettle();
          final loc = AppLocalizations.of(
            tester.element(find.byType(UnrelayedTransactionPanel)),
          );
          expect(retries, 0);
          expect(cancellations, 0);
          await tester.tap(find.text(loc.retry));
          await tester.pumpAndSettle();
          expect(retries, 1);
          await tester.tap(find.text(loc.cancel));
          await tester.pumpAndSettle();
          expect(
            find.text(loc.transactionCancelUnbroadcastTitle),
            findsOneWidget,
          );
          expect(cancellations, 0);
          await tester.tap(find.text(loc.transactionKeepTransaction));
          await tester.pumpAndSettle();
          expect(cancellations, 0);
          await tester.tap(find.text(loc.cancel));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(
            cancellations,
            0,
            reason: 'dismissing confirmation is not consent',
          );
          await tester.tap(find.text(loc.cancel));
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(BullDialog),
              matching: find.text(loc.cancel),
            ),
          );
          await tester.pumpAndSettle();
          expect(cancellations, 1);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('$locale dark=$dark busy actions and translated failures', (
        tester,
      ) async {
        var actions = 0;
        await tester.pumpWidget(
          _app(
            UnrelayedTransactionPanel(
              busy: true,
              failure: const TransactionCbfTorFailure(),
              onRetry: () => actions++,
              onCancel: () => actions++,
            ),
            locale,
            dark,
          ),
        );
        await tester.pumpAndSettle();
        final loc = AppLocalizations.of(
          tester.element(find.byType(UnrelayedTransactionPanel)),
        );
        expect(find.text(loc.transactionCbfTorUnavailable), findsOneWidget);
        expect(
          tester
              .widgetList<BullButton>(find.byType(BullButton))
              .every((button) => button.disabled),
          isTrue,
        );
        await tester.tap(find.text(loc.retry), warnIfMissed: false);
        await tester.tap(find.text(loc.cancel), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(actions, 0);
        expect(find.byType(BullDialog), findsNothing);
        for (final (failure, message) in [
          (
            const TransactionCbfRecoveryFailure(),
            loc.transactionCbfRecoveryFailed,
          ),
          (
            const TransactionCbfUnavailableFailure(),
            loc.transactionCbfUnavailable,
          ),
        ]) {
          await tester.pumpWidget(
            _app(
              UnrelayedTransactionPanel(
                failure: failure,
                onRetry: () {},
                onCancel: () {},
              ),
              locale,
              dark,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(message), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
