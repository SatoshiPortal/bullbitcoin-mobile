import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/load_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/save_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/presentation/autoswap_settings_cubit.dart';
import 'package:bb_mobile/features/autoswap/ui/screens/autoswap_settings_screen.dart';
import 'package:bb_mobile/features/autoswap/ui/widgets/autoswap_settings.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
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
    localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  tearDown(() async {
    await locator.reset();
  });

  testWidgets('renders a shared failure on the settings screen', (
    tester,
  ) async {
    final cubit = buildCubit();
    locator.registerFactory<AutoSwapSettingsCubit>(() => cubit);

    await tester.pumpWidget(app(const AutoSwapSettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Failed to load auto transfer settings'), findsOneWidget);
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

    expect(find.text('Failed to load auto transfer settings'), findsOneWidget);
  });
}
