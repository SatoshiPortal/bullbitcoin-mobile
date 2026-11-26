import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:startup/setup.dart' show StartupLocalizations;
import 'package:startup/startup.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  void setDisplay(WidgetTester tester, Locale locale) {
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<StartupLocalizations> pump(
    WidgetTester tester, {
    VoidCallback? onRetry,
    VoidCallback? onQuit,
  }) async {
    await tester.pumpWidget(
      BullSupportScope(
        onContactSupport: (_, {message}) {},
        child: InventoryUnreadableScreen(
          onRetry: onRetry ?? () {},
          onQuit: onQuit ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    return StartupLocalizations.of(tester.element(find.byType(Scaffold)));
  }

  testWidgets('offers only retry, support and quit, each by name', (
    tester,
  ) async {
    setDisplay(tester, const Locale('en', 'US'));
    final handle = tester.ensureSemantics();
    var retried = 0;
    var quit = 0;
    final loc = await pump(
      tester,
      onRetry: () => retried++,
      onQuit: () => quit++,
    );

    expect(find.text(loc.inventoryUnreadableTitle), findsOneWidget);
    expect(find.text(loc.inventoryUnreadableMessage), findsOneWidget);
    expect(find.bySemanticsLabel(loc.inventoryUnreadableTitle), findsWidgets);
    // Retry, support and quit: no reset, delete, reinstall or recover action.
    expect(find.byType(BullButton), findsNWidgets(3));
    expect(find.byType(BullSupportButton), findsOneWidget);
    await tester.tap(find.text(loc.retry));
    await tester.tap(find.text(loc.inventoryUnreadableQuitButton));
    expect(retried, 1);
    expect(quit, 1);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('retry runs once however often it is pressed', (tester) async {
    setDisplay(tester, const Locale('en', 'US'));
    var retried = 0;
    final loc = await pump(tester, onRetry: () => retried++);

    final retry = find.ancestor(
      of: find.text(loc.retry),
      matching: find.byType(BullButton),
    );
    expect(tester.widget<BullButton>(retry).disabled, isFalse);
    final position = tester.getCenter(retry);
    await tester.tapAt(position);
    await tester.pump();
    expect(retried, 1);
    expect(tester.widget<BullButton>(retry).disabled, isTrue);
    await tester.tapAt(position);
    await tester.pump();
    expect(retried, 1);
  });

  test('is translated beyond English', () async {
    final fr = await StartupLocalizations.delegate.load(const Locale('fr'));
    final en = await StartupLocalizations.delegate.load(const Locale('en'));
    expect(fr.inventoryUnreadableQuitButton, 'Quitter');
    expect(fr.inventoryUnreadableMessage, isNot(en.inventoryUnreadableMessage));
  });
}
