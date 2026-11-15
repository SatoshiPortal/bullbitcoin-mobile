import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/add_custom_server_bottom_sheet.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/localizations.dart';
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

  Future<void> openSheet(
    WidgetTester tester, {
    ValueChanged<CustomServerInput?>? onAdd,
  }) async {
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
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ElectrumSettingsBloc>.value(value: electrumBloc),
            BlocProvider<TorSettingsCubit>.value(value: torCubit),
          ],
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final input = await AddCustomServerBottomSheet.show(context);
                  onAdd?.call(input);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final validateDomain in [false, true]) {
    testWidgets('submits domain validation set to $validateDomain', (
      tester,
    ) async {
      CustomServerInput? result;
      await openSheet(tester, onAdd: (input) => result = input);
      final domainSwitch = find.widgetWithText(
        SwitchListTile,
        'Validate Domain',
      );
      expect(tester.widget<SwitchListTile>(domainSwitch).value, isFalse);
      await tester.enterText(
        find.byType(TextFormField),
        'electrum.example.com:50002',
      );
      if (validateDomain) {
        await tester.tap(domainSwitch);
        await tester.pump();
      }

      await tester.tap(find.text('Add Server'));
      await tester.pumpAndSettle();

      expect(result?.enableSsl, isTrue);
      expect(result?.validateDomain, validateDomain);
    });
  }

  testWidgets('opens Tor settings from an onion server input', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextFormField), 'hidden.onion:50002');
    await tester.pump();

    final sslSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(sslSwitch.value, isFalse);
    expect(sslSwitch.onChanged, isNull);
    expect(find.text('Validate Domain'), findsNothing);
    expect(find.text('Configure Tor'), findsNothing);

    await tester.tap(find.text('Tor'));
    await tester.pumpAndSettle();

    expect(find.text('Tor Settings'), findsOneWidget);
  });
}
