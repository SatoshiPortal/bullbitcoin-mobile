import 'package:bb_mobile/features/app_startup/public/app_startup_facade.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
    for (final name in ['secure-usb-drive', 'forgot-password']) {
      final loader = SvgAssetLoader('assets/misc/undraw_$name.svg');
      await svg.cache.putIfAbsent(
        loader.cacheKey(null),
        () => loader.loadBytes(null),
      );
    }
  });

  testWidgets('startup error exposes a retry for unavailable storage', (
    tester,
  ) async {
    _setDisplay(tester);
    var attempts = 0;
    Widget screen(VoidCallback retry) => BullSupportScope(
      onContactSupport: (_, {message}) {},
      child: AppInitErrorScreen(
        error: const LegacyImportUnavailable(),
        onRetry: retry,
      ),
    );
    await tester.pumpWidget(screen(() => attempts++));
    final loc = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    final button = find.text(loc.retry);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    expect(attempts, 1);

    await tester.pumpWidget(screen(() => attempts++));
    await tester.tap(button);
    expect(attempts, 2);
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('unknown route uses the localized error in ${theme.name}', (
      tester,
    ) async {
      _setDisplay(tester);
      final router = GoRouter(
        initialLocation: '/missing',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
        ],
        errorBuilder: (_, _) => const RouteErrorScreen(),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData(theme),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      final route = find.byType(RouteErrorScreen);
      expect(find.byType(BullScaffold), findsOneWidget);
      final loc = AppLocalizations.of(tester.element(route));
      expect(find.text(loc.coreScreensPageNotFound), findsOneWidget);
      expect(find.byType(BullButton), findsNothing);
    });

    testWidgets('startup error keeps its dark theme with ${theme.name} OS', (
      tester,
    ) async {
      _setDisplay(tester);
      tester.platformDispatcher.platformBrightnessTestValue =
          theme == AppThemeType.dark ? Brightness.dark : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      const example = 'Example startup failure';
      await tester.pumpWidget(
        BullSupportScope(
          onContactSupport: (_, {message}) {},
          child: AppInitErrorScreen(error: StateError(example)),
        ),
      );
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme!.brightness, Brightness.dark);
      final loc = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(loc.appInitErrorTitle), findsOneWidget);
      const details = 'Bad state: $example';
      expect(find.text(details), findsNothing);
      final detailsToggle = find.text(loc.appInitErrorDetailsToggle);
      await tester.scrollUntilVisible(detailsToggle, 250);
      await tester.tap(detailsToggle);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SelectableText, details), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(SelectableText, details));
      await tester.pumpAndSettle();
    });
  }
}

void _setDisplay(WidgetTester tester) {
  tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
