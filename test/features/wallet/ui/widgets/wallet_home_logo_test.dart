import 'package:bull_ui/app_theme.dart';
import 'package:settings/testing.dart';
import 'package:settings/settings.dart' show SuperuserTapUnlocker;
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_app_bar.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
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
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SettingsCubit>.value(
          value: settings,
          child: Scaffold(appBar: const WalletHomeAppBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.byType(SuperuserTapUnlocker);
    final loc = AppLocalizations.of(tester.element(target));
    final semantics = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel(loc.onboardingBullBitcoin), findsOneWidget);
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
