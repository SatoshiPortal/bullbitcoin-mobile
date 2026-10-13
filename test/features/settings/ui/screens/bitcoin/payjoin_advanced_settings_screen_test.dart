import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/payjoin_advanced_settings_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

Widget _buildPage(SettingsCubit settingsCubit) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SettingsCubit>.value(
    value: settingsCubit,
    child: const PayjoinAdvancedSettingsScreen(),
  ),
);

void main() {
  late _MockSettingsCubit settingsCubit;

  Finder minAmountField() => find.byType(TextField).at(0);
  Finder expiryField() => find.byType(TextField).at(1);

  setUp(() {
    settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => settingsCubit.state,
    ).thenReturn(SettingsState(payjoinPolicy: PayjoinPolicy.defaults()));
    when(
      () => settingsCubit.setPayjoinMinAmount(any()),
    ).thenAnswer((_) async {});
    when(
      () => settingsCubit.setPayjoinExpireAfterSec(any()),
    ).thenAnswer((_) async {});
  });

  testWidgets('shows the stored expiry in minutes with its units', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(settingsCubit));

    expect(find.text('1440'), findsOneWidget);
    expect(find.text('10000'), findsOneWidget);
    expect(find.text('min'), findsOneWidget);
    expect(find.text('sats'), findsOneWidget);
  });

  testWidgets('saves an expiry typed in minutes as seconds', (tester) async {
    await tester.pumpWidget(_buildPage(settingsCubit));

    await tester.enterText(expiryField(), '30');
    await tester.pump(const Duration(seconds: 1));

    verify(() => settingsCubit.setPayjoinExpireAfterSec(1800)).called(1);
  });

  testWidgets('rejects an expiry above 24 hours', (tester) async {
    await tester.pumpWidget(_buildPage(settingsCubit));

    await tester.enterText(expiryField(), '1441');
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Must be between 1 and 1440 minutes'), findsOneWidget);
    verifyNever(() => settingsCubit.setPayjoinExpireAfterSec(any()));
  });

  testWidgets('keeps only digits in the minimum amount', (tester) async {
    await tester.pumpWidget(_buildPage(settingsCubit));

    await tester.enterText(minAmountField(), '-12.5,00');
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('12500'), findsOneWidget);
    verify(() => settingsCubit.setPayjoinMinAmount(12500)).called(1);
  });
}
