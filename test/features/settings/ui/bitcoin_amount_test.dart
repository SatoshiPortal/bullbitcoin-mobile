import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SettingsCubit extends Mock implements SettingsCubit {}

void main() {
  testWidgets('reads default, toggles locally and never writes preferences', (
    tester,
  ) async {
    final cubit = _SettingsCubit();
    when(() => cubit.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.btc,
          currencyCode: 'USD',
          hideAmounts: false,
        ),
      ),
    );
    when(
      () => cubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: const Scaffold(body: BitcoinAmountView(1)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0.00000001 BTC'), findsOneWidget);
    clearInteractions(cubit);
    await tester.tap(find.byType(BullAmountUnitToggle));
    await tester.pump();
    expect(find.text('1 sats'), findsOneWidget);
    verifyNever(() => cubit.toggleSatsUnit(any()));
    expect(cubit.state.bitcoinUnit, BitcoinUnit.btc);
  });

  testWidgets('hidden amount stays masked through a local toggle', (
    tester,
  ) async {
    final cubit = _SettingsCubit();
    when(() => cubit.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          hideAmounts: true,
        ),
      ),
    );
    when(
      () => cubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: const Scaffold(body: BitcoinAmountView(12345)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('** sats'), findsOneWidget);
    await tester.tap(find.byType(BullAmountUnitToggle));
    await tester.pump();
    expect(find.text('** BTC'), findsOneWidget);
    expect(find.textContaining('12345'), findsNothing);
  });
}
