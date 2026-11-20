import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

const _done = 'Terminé';

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
            theme: ThemeData(extensions: testBullExtensions),
            // The official bridge supports keyboard_actions' SDK widgets.
            // ignore: deprecated_member_use
            builder: (context, child) => MaterialUiCompatibilityBridge(
              child: child ?? const SizedBox.shrink(),
            ),
            home: Scaffold(
              body: BullKeyboardActions(
                doneText: _done,
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
        expect(find.text(_done), findsOneWidget);
        if (navigation) {
          await tester.tap(find.byTooltip('Next'));
          await tester.pumpAndSettle();
          expect(second.hasFocus, isTrue);
        } else {
          expect(find.byTooltip('Next'), findsNothing);
        }
        await tester.tap(find.text(_done));
        await tester.pumpAndSettle();
        expect(first.hasFocus || second.hasFocus, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('forwards scroll policy and uses the design-system palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const BullKeyboardActions(
          doneText: _done,
          disableScroll: true,
          child: TextField(),
        ),
      ),
    );

    final accessory = tester.widget<KeyboardActions>(
      find.byType(KeyboardActions),
    );
    expect(accessory.ensureVisible, isFalse);
    expect(accessory.theme?.barColor, testBullTheme.surface);
    expect(accessory.theme?.foregroundColor, testBullTheme.onSurface);
  });

  testWidgets('Android retains the system keyboard without an accessory bar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        // The official bridge supports keyboard_actions' SDK widgets.
        // ignore: deprecated_member_use
        builder: (context, child) => MaterialUiCompatibilityBridge(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(
          body: BullKeyboardActions(doneText: _done, child: TextField()),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text(_done), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
