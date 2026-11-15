import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final navigation in [true, false]) {
    testWidgets(
      'iOS keyboard navigation=$navigation uses the French Done action',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        final first = FocusNode();
        final second = FocusNode();
        addTearDown(first.dispose);
        addTearDown(second.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fr'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            theme: AppTheme.themeData(AppThemeType.dark),
            // The official bridge supports keyboard_actions' SDK widgets.
            // ignore: deprecated_member_use
            builder: (context, child) => MaterialUiCompatibilityBridge(
              child: child ?? const SizedBox.shrink(),
            ),
            home: Scaffold(
              body: BBKeyboardActions(
                nextFocus: navigation,
                child: ListView(
                  children: [
                    TextField(key: const Key('first'), focusNode: first),
                    TextField(key: const Key('second'), focusNode: second),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.showKeyboard(find.byKey(const Key('first')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final done = lookupAppLocalizations(const Locale('fr')).doneButton;
        expect(find.text(done), findsOneWidget);
        if (navigation) {
          await tester.tap(find.byTooltip('Next'));
          await tester.pumpAndSettle();
          expect(second.hasFocus, isTrue);
        } else {
          expect(find.byTooltip('Next'), findsNothing);
        }
        await tester.tap(find.text(done));
        await tester.pumpAndSettle();
        expect(first.hasFocus || second.hasFocus, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Android retains the system keyboard without an accessory bar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.themeData(AppThemeType.dark),
        // The official bridge supports keyboard_actions' SDK widgets.
        // ignore: deprecated_member_use
        builder: (context, child) => MaterialUiCompatibilityBridge(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: BBKeyboardActions(child: TextField())),
      ),
    );
    await tester.showKeyboard(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      find.text(lookupAppLocalizations(const Locale('en')).doneButton),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
