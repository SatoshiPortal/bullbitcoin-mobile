import '../../../fixtures.dart';

import 'package:network/src/electrum_settings/ui/widgets/add_custom_server_bottom_sheet.dart';
import 'package:network/src/electrum_settings/presentation/electrum_settings_bloc.dart';
import 'package:network/src/tor_settings/presentation/tor_settings_cubit.dart';
import 'package:network/generated/l10n/network_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockElectrumSettingsBloc extends Mock implements ElectrumSettingsBloc {}

class _MockTorSettingsCubit extends Mock implements TorSettingsCubit {}

void main() {
  group('isOnionCustomServerInput', () {
    test('recognizes supported onion server formats', () {
      expect(isOnionCustomServerInput('hidden.onion:50002'), isTrue);
      expect(isOnionCustomServerInput('hidden.onion:50002:t'), isTrue);
      expect(isOnionCustomServerInput('hidden.onion:50002:s'), isTrue);
    });

    test('rejects clearnet and incomplete inputs', () {
      expect(isOnionCustomServerInput('electrum.example.com:50002'), isFalse);
      expect(isOnionCustomServerInput('hidden.onion'), isFalse);
      expect(isOnionCustomServerInput(''), isFalse);
    });
  });

  testWidgets('opens Tor settings from an onion server input', (tester) async {
    final electrumBloc = _MockElectrumSettingsBloc();
    when(() => electrumBloc.state).thenReturn(const ElectrumSettingsState());
    when(() => electrumBloc.stream)
        .thenAnswer((_) => const Stream<ElectrumSettingsState>.empty());
    final torCubit = _MockTorSettingsCubit();
    when(() => torCubit.state).thenReturn(const TorSettingsState());
    when(() => torCubit.stream)
        .thenAnswer((_) => const Stream<TorSettingsState>.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: networkTestTheme(),
        localizationsDelegates: networkTestLocalizationsDelegates,
        supportedLocales: NetworkLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ElectrumSettingsBloc>.value(value: electrumBloc),
            BlocProvider<TorSettingsCubit>.value(value: torCubit),
          ],
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AddCustomServerBottomSheet.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'hidden.onion:50002');
    await tester.pump();

    final sslSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(sslSwitch.value, isFalse);
    expect(sslSwitch.onChanged, isNull);
    expect(find.text('Configure Tor'), findsNothing);

    await tester.tap(find.text('Tor'));
    await tester.pumpAndSettle();

    expect(find.text('Tor Settings'), findsOneWidget);
  });
}
