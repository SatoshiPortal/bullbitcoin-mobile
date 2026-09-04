import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/coins/ui/widgets/coins_selection_bar.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

void main() {
  testWidgets('shows Send and Sweep only for fully spendable coins', (
    tester,
  ) async {
    var sends = 0;
    var sweeps = 0;
    final settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          hideAmounts: false,
        ),
      ),
    );
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());

    Widget buildApp({required bool anyFrozen}) => MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<SettingsCubit>.value(
        value: settingsCubit,
        child: Scaffold(
          bottomNavigationBar: CoinsSelectionBar(
            selectedCount: 2,
            selectedTotalSat: BigInt.from(75000),
            anyUnfrozen: true,
            anyFrozen: anyFrozen,
            onSend: () => sends++,
            onSweep: () => sweeps++,
            onFreeze: () {},
            onUnfreeze: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildApp(anyFrozen: false));

    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Sweep'), findsOneWidget);
    expect(find.textContaining('75,000'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.tap(find.text('Sweep'));

    expect(sends, 1);
    expect(sweeps, 1);

    await tester.pumpWidget(buildApp(anyFrozen: true));

    expect(find.text('Send'), findsNothing);
    expect(find.text('Sweep'), findsNothing);
  });
}
