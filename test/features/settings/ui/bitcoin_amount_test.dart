import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
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
          child: const Scaffold(
            body: CurrencyText(1, showFiat: false, interactive: true),
          ),
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
          child: const Scaffold(
            body: CurrencyText(12345, showFiat: false, interactive: true),
          ),
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
  testWidgets('explicit fiat remains text and follows the privacy setting', (
    tester,
  ) async {
    final cubit = _SettingsCubit();
    SettingsState state(bool hidden) => SettingsState(
      storedSettings: SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'USD',
        hideAmounts: hidden,
      ),
    );
    var current = state(false);
    when(() => cubit.state).thenAnswer((_) => current);
    when(
      () => cubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    Widget screen() => MaterialApp(
      home: BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: const Scaffold(
          body: CurrencyText(
            123,
            showFiat: false,
            fiatAmount: 12.5,
            fiatCurrency: 'USD',
            interactive: true,
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen());
    expect(find.text('12.50 USD'), findsOneWidget);
    expect(find.byType(BullAmountUnitToggle), findsNothing);
    current = state(true);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(screen());
    expect(find.text('** USD'), findsOneWidget);
    expect(find.text('12.50 USD'), findsNothing);
    expect(find.byType(BullAmountUnitToggle), findsNothing);
  });
}
