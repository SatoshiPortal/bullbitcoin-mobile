import 'package:exchange/exchange.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/announcement_banner.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart'
    show FontLoader, TextSelection, rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeCubit {}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('exchange announcement sheet in ${theme.name}', (tester) async {
      const title = 'Scheduled maintenance';
      final exchange = _Exchange();
      when(() => exchange.stream).thenAnswer((_) => const Stream.empty());
      when(() => exchange.state).thenReturn(
        ExchangeState(
          announcements: [
            Announcement(
              title: title,
              description: 'Exchange services will be unavailable during scheduled maintenance.',
              updatedAt: DateTime.utc(2026, 11, 20),
            ),
          ],
        ),
      );
      await _pump(
        tester,
        theme,
        BlocProvider<ExchangeCubit>.value(
          value: exchange,
          child: const AnnouncementBanner(),
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
      ...appLocalizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: content)),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}
