import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/swap/presentation/swap_settings_cubit.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_settings_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapSettingsCubit extends Mock implements SwapSettingsCubit {}

void main() {
  late _MockSwapSettingsCubit cubit;

  Future<void> pump(WidgetTester tester, SwapSettingsState state) async {
    cubit = _MockSwapSettingsCubit();
    when(() => cubit.state).thenReturn(state);
    when(
      () => cubit.stream,
    ).thenAnswer((_) => StreamController<SwapSettingsState>.broadcast().stream);
    when(() => cubit.close()).thenAnswer((_) async {});
    when(
      () => cubit.setExchangeFallbackEnabled(any()),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SwapSettingsCubit>.value(
          value: cubit,
          child: const SwapSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the provider override is offered only in dev mode', (
    tester,
  ) async {
    await pump(tester, const SwapSettingsState(loaded: true));
    expect(find.text('Swap provider'), findsNothing);

    await pump(
      tester,
      const SwapSettingsState(loaded: true, devModeEnabled: true),
    );
    expect(find.text('Swap provider'), findsOneWidget);
    expect(find.text('Boltz only'), findsOneWidget);
  });

  testWidgets('the fallback switch turns the fallback on', (tester) async {
    await pump(tester, const SwapSettingsState(loaded: true));

    await tester.tap(find.byType(Switch));
    await tester.pump();

    verify(() => cubit.setExchangeFallbackEnabled(true)).called(1);
  });

  testWidgets('the switch is inert until the stored value is known', (
    tester,
  ) async {
    await pump(tester, const SwapSettingsState());

    await tester.tap(find.byType(Switch));
    await tester.pump();

    verifyNever(() => cubit.setExchangeFallbackEnabled(any()));
  });
}
