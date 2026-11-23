import 'package:bull_ui/app_theme.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';
import 'package:swap_feature/testing.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoadAutoswapSettingsUsecase extends Mock
    implements LoadAutoswapSettingsUsecase {}

class MockSaveAutoswapSettingsUsecase extends Mock
    implements SaveAutoswapSettingsUsecase {}

void main() {
  late MockLoadAutoswapSettingsUsecase load;
  late MockSaveAutoswapSettingsUsecase save;

  AutoSwapSettingsCubit buildCubit() => AutoSwapSettingsCubit(
    loadAutoswapSettingsUsecase: load,
    saveAutoswapSettingsUsecase: save,
  );

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  setUp(() {
    load = MockLoadAutoswapSettingsUsecase();
    save = MockSaveAutoswapSettingsUsecase();
    when(() => load.execute()).thenAnswer(
      (_) async => const Err(AutoswapSettingsUnavailableFailure('_Exception')),
    );
  });

  testWidgets('renders a shared failure on the settings screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        BlocProvider(
          create: (_) => buildCubit()..loadSettings(),
          child: const AutoSwapSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load auto swap settings'), findsOneWidget);
  });

  testWidgets('renders a shared failure in the settings bottom sheet', (
    tester,
  ) async {
    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.loadSettings();

    await tester.pumpWidget(
      app(
        BlocProvider.value(
          value: cubit,
          child: const AutoSwapSettingsContent(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load auto swap settings'), findsOneWidget);
  });
}
