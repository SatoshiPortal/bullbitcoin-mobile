import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_amount_scope.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SettingsCubit extends Mock implements SettingsCubit {}

SettingsState _state(BitcoinUnit unit) => SettingsState(
  storedSettings: SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: unit,
    currencyCode: 'USD',
    hideAmounts: false,
  ),
);

void main() {
  testWidgets('exposes the default unit, localized messages and writer', (
    tester,
  ) async {
    final cubit = _SettingsCubit();
    var state = _state(BitcoinUnit.btc);
    when(() => cubit.state).thenAnswer((_) => state);
    when(
      () => cubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => cubit.toggleSatsUnit(any())).thenAnswer((invocation) async {
      final active = invocation.positionalArguments.single as bool;
      state = _state(active ? BitcoinUnit.sats : BitcoinUnit.btc);
    });
    BullAmountPreferences? found;
    AppLocalizations? localizations;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: SettingsAmountScope(
            child: Builder(
              builder: (context) {
                found = BullAmountPreferencesScope.maybeOf(context);
                localizations = AppLocalizations.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    final preferences = found;
    final loc = localizations;
    expect(preferences, isNotNull);
    expect(loc, isNotNull);
    if (preferences == null || loc == null) throw StateError('Missing scope');
    expect(preferences.defaultUnit, BullAmountUnit.btc);
    expect(preferences.globalActionLabel, loc.amountChangeDefaultEverywhere);
    expect(preferences.tooltip, loc.amountGesturesHint);
    expect(
      preferences.satsEverywhereMessage,
      loc.amountsDisplayedEverywhereSats,
    );
    expect(preferences.btcEverywhereMessage, loc.amountsDisplayedEverywhereBtc);
    expect(preferences.undoLabel, loc.amountUndo);
    expect(preferences.failureMessage, loc.oopsSomethingWentWrong);
    expect(await preferences.changeDefaultUnit(BullAmountUnit.sats), isTrue);
    verify(() => cubit.toggleSatsUnit(true)).called(1);
    expect(cubit.state.bitcoinUnit, BitcoinUnit.sats);
    expect(await preferences.changeDefaultUnit(BullAmountUnit.btc), isTrue);
    verify(() => cubit.toggleSatsUnit(false)).called(1);
    expect(cubit.state.bitcoinUnit, BitcoinUnit.btc);
  });

  testWidgets('reports failure when the requested unit was not stored', (
    tester,
  ) async {
    final cubit = _SettingsCubit();
    when(() => cubit.state).thenReturn(_state(BitcoinUnit.btc));
    when(
      () => cubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => cubit.toggleSatsUnit(any())).thenAnswer((_) async {});
    BullAmountPreferences? found;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: SettingsAmountScope(
            child: Builder(
              builder: (context) {
                found = BullAmountPreferencesScope.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    final preferences = found;
    expect(preferences, isNotNull);
    if (preferences == null) throw StateError('Missing scope');
    expect(await preferences.changeDefaultUnit(BullAmountUnit.sats), isFalse);
    verify(() => cubit.toggleSatsUnit(true)).called(1);
    expect(cubit.state.bitcoinUnit, BitcoinUnit.btc);
  });
}
