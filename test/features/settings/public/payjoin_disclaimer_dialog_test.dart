import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/public/payjoin_disclaimer_dialog.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requires the explicit OK action', (tester) async {
    bool? accepted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              accepted = await PayjoinDisclaimerDialog.show(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Payjoin disclaimer'), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text('Payjoin disclaimer'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Payjoin disclaimer'), findsOneWidget);
    expect(accepted, isNull);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });
}
