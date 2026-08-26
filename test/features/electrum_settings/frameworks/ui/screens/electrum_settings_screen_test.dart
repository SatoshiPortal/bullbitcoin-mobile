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

Future<void> _pumpScreen(
  WidgetTester tester, {
  required bool torAvailable,
}) async {
  final electrumBloc = _MockElectrumSettingsBloc();
  when(() => electrumBloc.state).thenReturn(
    ElectrumSettingsState(hasActiveCustomBitcoinOnionServer: torAvailable),
  );
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
  testWidgets('keeps Tor disabled without an active custom Bitcoin onion', (
    tester,
  ) async {
    await _pumpScreen(tester, torAvailable: false);

    await tester.tap(find.text('Tor'));
    await tester.pumpAndSettle();

    expect(find.text('Local SOCKS5 proxy (advanced)'), findsNothing);
  });

  testWidgets('shows the shared Tor panel for an active custom Bitcoin onion', (
    tester,
  ) async {
    await _pumpScreen(tester, torAvailable: true);

    await tester.tap(find.text('Tor'));
    await tester.pumpAndSettle();

    expect(find.text('Local SOCKS5 proxy (advanced)'), findsOneWidget);
  });
}
