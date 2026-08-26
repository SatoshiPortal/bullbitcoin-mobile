import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/screens/electrum_settings_screen.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockElectrumSettingsBloc extends Mock implements ElectrumSettingsBloc {}

class _MockTorSettingsCubit extends Mock implements TorSettingsCubit {}

Future<void> _pumpScreen(WidgetTester tester) async {
  final electrumBloc = _MockElectrumSettingsBloc();
  when(() => electrumBloc.state).thenReturn(const ElectrumSettingsState());
  when(
    () => electrumBloc.stream,
  ).thenAnswer((_) => const Stream<ElectrumSettingsState>.empty());
  final torCubit = _MockTorSettingsCubit();
  when(() => torCubit.state).thenReturn(const TorSettingsState());
  when(
    () => torCubit.stream,
  ).thenAnswer((_) => const Stream<TorSettingsState>.empty());

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ElectrumSettingsBloc>.value(value: electrumBloc),
        BlocProvider<TorSettingsCubit>.value(value: torCubit),
      ],
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ElectrumSettingsScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('keeps network selection limited to Bitcoin and Liquid', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('Liquid'), findsOneWidget);
    expect(find.text('Tor'), findsNothing);
  });
}
