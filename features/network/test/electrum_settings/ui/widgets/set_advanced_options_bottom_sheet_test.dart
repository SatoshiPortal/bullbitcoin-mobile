import '../../../fixtures.dart';

import 'package:network/src/electrum_settings/ui/widgets/set_advanced_options_bottom_sheet.dart';
import 'package:network/src/electrum_settings/presentation/electrum_advanced_options_view_model.dart';
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
  group('shouldShowTorInAdvancedOptions', () {
    test('shows Tor only for an active custom Bitcoin onion', () {
      expect(
        shouldShowTorInAdvancedOptions(
          const ElectrumSettingsState(hasActiveCustomBitcoinOnionServer: true),
        ),
        isTrue,
      );
      expect(
        shouldShowTorInAdvancedOptions(
          const ElectrumSettingsState(hasActiveCustomBitcoinOnionServer: false),
        ),
        isFalse,
      );
      expect(
        shouldShowTorInAdvancedOptions(
          const ElectrumSettingsState(
            isLiquid: true,
            hasActiveCustomBitcoinOnionServer: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('field labels', () {
    Future<void> openSheet(WidgetTester tester) async {
      final electrumBloc = _MockElectrumSettingsBloc();
      when(() => electrumBloc.state).thenReturn(
        const ElectrumSettingsState(
          advancedOptions: ElectrumAdvancedOptionsViewModel(
            stopGap: 20,
            timeout: 5,
            retry: 5,
            validateDomain: true,
          ),
        ),
      );
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
                  onPressed: () => SetAdvancedOptionsBottomSheet.show(context),
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

    testWidgets('names each number field with its visible label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openSheet(tester);

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(3));
      expect(
        tester.getSemantics(fields.at(0)),
        isSemantics(label: 'Stop Gap', value: '20', isTextField: true),
      );
      expect(
        tester.getSemantics(fields.at(1)),
        isSemantics(label: 'Timeout (seconds)', value: '5', isTextField: true),
      );
      expect(
        tester.getSemantics(fields.at(2)),
        isSemantics(label: 'Retry Count', value: '5', isTextField: true),
      );

      semantics.dispose();
    });

    testWidgets('keeps one label per field once the value is cleared', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openSheet(tester);

      final fields = find.byType(TextFormField);
      for (var index = 0; index < 3; index++) {
        await tester.enterText(fields.at(index), '');
      }
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(fields.at(0)),
        isSemantics(label: 'Stop Gap', isTextField: true),
      );
      expect(
        tester.getSemantics(fields.at(1)),
        isSemantics(label: 'Timeout (seconds)', isTextField: true),
      );
      expect(
        tester.getSemantics(fields.at(2)),
        isSemantics(label: 'Retry Count', isTextField: true),
      );

      semantics.dispose();
    });
  });
}
