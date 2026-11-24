import 'dart:io';

import 'package:exchange/exchange.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_exchange/testing.dart';
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show ByteData, FontLoader, TextSelection;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    // The font is an app asset, not this package's: read it from the repo.
    await (FontLoader('Golos Text')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('../../assets/fonts/GolosText.ttf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('exchange announcement sheet in ${theme.name}', (tester) async {
      const title = 'Scheduled maintenance';
      await _pump(
        tester,
        theme,
        AnnouncementBanner(
          announcements: [
            Announcement(
              title: title,
              description: 'Exchange services will be unavailable during scheduled maintenance.',
              updatedAt: DateTime.utc(2026, 11, 20),
            ),
          ],
        ),
      );

      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(BullBottomSheet), findsOneWidget);
      final close = MaterialLocalizations.of(
        tester.element(find.byType(BottomSheet)),
      ).closeButtonTooltip;
      final closeButton = find.byTooltip(close);
      expect(
        tester.getSize(closeButton).shortestSide,
        greaterThanOrEqualTo(48),
      );

      final sheetTitle = find.descendant(
        of: find.byType(BullBottomSheet),
        matching: find.text(title),
      );
      Set<double> titleLines() => tester
          .renderObject<RenderParagraph>(sheetTitle)
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: title.length),
          )
          .map((box) => box.top)
          .toSet();

      expect(titleLines(), hasLength(1));
      expect(tester.getCenter(closeButton).dx, 354);

      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(titleLines().length, greaterThan(1));
      expect(
        tester.getSize(closeButton).shortestSide,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  AppThemeType theme,
  Widget content,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.themeData(theme),
    localizationsDelegates: const [
      bullUiLocalizationsDelegate,
      ...ExchangeLocalizations.localizationsDelegates,
    ],
    supportedLocales: ExchangeLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: content)),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}
