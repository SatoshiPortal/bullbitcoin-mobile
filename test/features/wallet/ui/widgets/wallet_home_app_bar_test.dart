import 'dart:ui' show SemanticsAction;

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_app_bar.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _SettingsCubit extends Mock implements SettingsCubit {}

Future<_SettingsCubit> _paint(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  List<bool>? toggles,
}) async {
  final cubit = _SettingsCubit();
  when(() => cubit.state).thenReturn(
    const SettingsState(
      storedSettings: SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        isSuperuser: false,
      ),
    ),
  );
  when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => cubit.toggleSuperuserMode(true)).thenAnswer((_) async {
    toggles?.add(true);
  });
  await tester.pumpWidget(
    BlocProvider<SettingsCubit>.value(
      value: cubit,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.themeData(AppThemeType.light),
        home: const Scaffold(appBar: WalletHomeAppBar()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

Finder namedButton(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == label &&
      widget.properties.button == true,
);

Finder logoImage() => find.descendant(
  of: find.byType(TopBarBullLogo),
  matching: find.byType(Image),
);

void main() {
  for (final locale in [const Locale('en'), const Locale('fr')]) {
    testWidgets(
      'home logo is one localized 48 dp button in ${locale.languageCode}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await _paint(tester, locale: locale);
          final label = lookupAppLocalizations(locale).onboardingBullBitcoin;
          final named = find.semantics.byLabel(label);
          expect(named.evaluate(), hasLength(1));
          final node = named.evaluate().single;
          final data = node.getSemanticsData();
          expect(data.flagsCollection.isButton, true);
          expect(data.hasAction(SemanticsAction.tap), true);
          expect(node.rect.width, greaterThanOrEqualTo(48));
          expect(node.rect.height, greaterThanOrEqualTo(48));
          final target = tester.getRect(namedButton(label));
          expect(target.size, const Size(48, 48));
          final image = logoImage();
          expect(image, findsOneWidget);
          // getRect applies the render transform; getSize reports layout size.
          expect(tester.getSize(image), const Size(48, 48));
          final painted = tester.getRect(image);
          expect(painted.width, closeTo(40, 0.001));
          expect(painted.height, closeTo(40, 0.001));
          expect((painted.center - target.center).distance, closeTo(0, 0.001));
          expect(Localizations.localeOf(tester.element(image)), locale);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('semantic and edge taps share one seven-tap unlocker', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final toggles = <bool>[];
      final cubit = await _paint(tester, toggles: toggles);
      final label = lookupAppLocalizations(const Locale('en'))
          .onboardingBullBitcoin;
      final named = find.semantics.byLabel(label);
      expect(named.evaluate(), hasLength(1));
      final target = tester.getRect(namedButton(label));
      final painted = tester.getRect(logoImage());
      final edge = Offset(target.left + 2, target.center.dy);
      // Both rectangles and this point use the same global logical coordinates.
      expect(target.contains(edge), true);
      expect(painted.contains(edge), false);
      tester.semantics.tap(named);
      await tester.pump(const Duration(milliseconds: 50));
      for (var total = 2; total <= 6; total++) {
        await tester.tapAt(edge);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(toggles, isEmpty);
      await tester.tapAt(edge);
      await tester.pump(const Duration(milliseconds: 50));
      expect(toggles, [true]);
      await tester.tapAt(edge);
      await tester.pump(const Duration(milliseconds: 50));
      expect(toggles, [true]);
      verify(() => cubit.toggleSuperuserMode(true)).called(1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    } finally {
      semantics.dispose();
    }
  });
}
