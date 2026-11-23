import 'package:bull_ui/app_theme.dart';
import 'package:settings/testing.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('developer mode warning in ${theme.name}', (tester) async {
      final settings = _Settings();
      when(() => settings.state).thenReturn(const SettingsState());
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      when(() => settings.toggleDevMode(true)).thenAnswer((_) async {});
      final loc = await _pump(
        tester,
        theme,
        const Scaffold(body: Center(child: DevModeSwitch())),
        wrap: (child) =>
            BlocProvider<SettingsCubit>.value(value: settings, child: child),
      );
      final toggle = find.byType(Switch);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final sheet = find.byType(BullBottomSheet);
      expect(sheet, findsOneWidget);
      expect(find.text(loc.settingsDevModeWarningTitle), findsOneWidget);
      verifyNever(() => settings.toggleDevMode(true));

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      verifyNever(() => settings.toggleDevMode(true));

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.settingsDevModeUnderstandButton));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      verify(() => settings.toggleDevMode(true)).called(1);
    });
  }
}

Future<SettingsLocalizations> _pump(
  WidgetTester tester,
  AppThemeType theme,
  Widget screen, {
  Widget Function(Widget)? wrap,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
  );
  addTearDown(router.dispose);
  final app = MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.themeData(theme),
    localizationsDelegates: const [
      bullUiLocalizationsDelegate,
      ...settingsTestLocalizationsDelegates,
    ],
    supportedLocales: SettingsLocalizations.supportedLocales,
    routerConfig: router,
  );
  await tester.pumpWidget(wrap?.call(app) ?? app);
  await tester.pumpAndSettle();
  return SettingsLocalizations.of(tester.element(find.byType(Scaffold)));
}
