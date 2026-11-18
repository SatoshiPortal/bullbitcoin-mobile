import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:bb_mobile/features/mempool_settings/ui/widgets/add_custom_server_button.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MempoolSettingsCubit extends MockCubit<MempoolSettingsState>
    implements MempoolSettingsCubit {}

Future<void> _pump(WidgetTester tester, MempoolSettingsState state) async {
  final cubit = _MempoolSettingsCubit();
  when(() => cubit.state).thenReturn(state);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<MempoolSettingsCubit>.value(
        value: cubit,
        child: const Scaffold(body: AddCustomServerButton()),
      ),
    ),
  );
}

void main() {
  testWidgets('the add button keeps its name and its tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const MempoolSettingsState());

    expect(
      tester.getSemantics(find.bySemanticsLabel('Add Custom Server')),
      isSemantics(isButton: true, hasTapAction: true, isEnabled: true),
    );
    semantics.dispose();
  });

  testWidgets('the add button is disabled while a save is in flight', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const MempoolSettingsState(isSavingServer: true));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Add Custom Server')),
      isSemantics(isButton: true, hasTapAction: false, isEnabled: false),
    );
    semantics.dispose();
  });
}
