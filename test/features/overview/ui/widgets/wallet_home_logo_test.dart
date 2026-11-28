import 'package:bull_ui/app_theme.dart';
import 'package:settings/testing.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
  for (final theme in AppThemeType.values) {
    testWidgets('wallet chrome keeps the light system overlay in $theme', (
      tester,
    ) async {
      final settings = _Settings();
      when(() => settings.state).thenReturn(const SettingsState());
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(theme),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<SettingsCubit>.value(
            value: settings,
            child: Scaffold(appBar: AppRouter.walletHomeAppBar()),
          ),
        ),
      );
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.systemOverlayStyle, SystemUiOverlayStyle.light);
      expect(appBar.automaticallyImplyLeading, isFalse);
      expect(appBar.centerTitle, isTrue);
      expect(appBar.elevation, 0);
      expect(appBar.scrolledUnderElevation, 0);
      expect(AppRouter.walletHomeAppBar().preferredSize.height, kToolbarHeight);
    });
  }

  testWidgets('the wallet logo keeps its size and seven-tap activation', (
    tester,
  ) async {
    final settings = _Settings();
    when(() => settings.state).thenReturn(const SettingsState());
    when(() => settings.stream).thenAnswer((_) => const Stream.empty());
    when(() => settings.toggleSuperuserMode(true)).thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SettingsCubit>.value(
          value: settings,
          child: Scaffold(appBar: AppRouter.walletHomeAppBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.byType(SuperuserTapUnlocker);
    final loc = SettingsLocalizations.of(tester.element(target));
    expect(loc.localeName, 'fr');
    final semantics = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel(loc.onboardingBullBitcoin), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(loc.onboardingBullBitcoin)),
        isSemantics(
          label: loc.onboardingBullBitcoin,
          isButton: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
    expect(tester.getSize(target), const Size.square(48));
    expect(
      tester.getSize(find.descendant(of: target, matching: find.byType(Image))),
      const Size.square(40),
    );

    final margin = tester.getCenter(target) + const Offset(23, 0);
    for (var i = 0; i < 6; i++) {
      await tester.tapAt(margin);
      await tester.pump();
    }
    verifyNever(() => settings.toggleSuperuserMode(true));
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.tapAt(margin);
    await tester.pump();
    verifyNever(() => settings.toggleSuperuserMode(true));

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(margin);
    }
    await tester.pumpAndSettle();
    verify(() => settings.toggleSuperuserMode(true)).called(1);
    expect(find.text(loc.settingsSuperuserModeUnlockedMessage), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
