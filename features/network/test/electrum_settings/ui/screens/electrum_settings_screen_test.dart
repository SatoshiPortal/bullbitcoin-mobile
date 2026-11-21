import '../../../fixtures.dart';

import 'package:network/src/electrum_settings/ui/screens/electrum_settings_screen.dart';
import 'package:network/src/electrum_settings/presentation/electrum_settings_bloc.dart';
import 'package:network/src/tor_settings/presentation/tor_settings_cubit.dart';
import 'package:network/generated/l10n/network_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockElectrumSettingsBloc extends Mock implements ElectrumSettingsBloc {}

class _MockTorSettingsCubit extends Mock implements TorSettingsCubit {}

Future<void> _pumpScreen(WidgetTester tester) async {
  final electrumBloc = _MockElectrumSettingsBloc();
  when(() => electrumBloc.state).thenReturn(const ElectrumSettingsState());
  when(() => electrumBloc.stream)
      .thenAnswer((_) => const Stream<ElectrumSettingsState>.empty());
  final torCubit = _MockTorSettingsCubit();
  when(() => torCubit.state).thenReturn(const TorSettingsState());
  when(() => torCubit.stream)
      .thenAnswer((_) => const Stream<TorSettingsState>.empty());

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ElectrumSettingsBloc>.value(value: electrumBloc),
        BlocProvider<TorSettingsCubit>.value(value: torCubit),
      ],
      child: MaterialApp(
        theme: networkTestTheme(),
        localizationsDelegates: networkTestLocalizationsDelegates,
        supportedLocales: NetworkLocalizations.supportedLocales,
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
