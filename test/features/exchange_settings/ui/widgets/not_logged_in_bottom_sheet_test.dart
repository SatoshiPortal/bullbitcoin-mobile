import 'package:bull_ui/app_theme.dart';
import 'package:bull_exchange/testing.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullText;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final themeType in AppThemeType.values) {
    testWidgets(
      'the login label stays readable in the ${themeType.name} theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(themeType),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => NotLoggedInBottomSheet(
                  message: AppLocalizations.of(context).notLoggedInMessage,
                  onSignIn: () {},
                ),
              ),
            ),
          ),
        );

        final scope = find.byType(BullButton);
        final fill =
            tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: scope,
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        final text = tester.widget<BullText>(
          find.descendant(of: scope, matching: find.byType(BullText)),
        );
        expect(text.color, isNot(fill.color));
      },
    );
  }
}
