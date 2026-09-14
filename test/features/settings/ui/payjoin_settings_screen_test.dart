import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/switch/bb_switch.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/payjoin_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

/// The Payjoin entry moved into Wallet and Bitcoin; its nested controls are
/// the ones a move is most likely to break, so they are driven, not found.
void main() {
  final english = AppLocalizationsEn();

  testWidgets('the advanced page appears only once payjoin is enabled', (
    tester,
  ) async {
    final cubit = _cubit(enabled: false);
    await _pump(tester, cubit);

    expect(find.text(english.settingsPayjoinAdvancedTitle), findsNothing);

    await _pump(tester, _cubit(enabled: true));

    expect(find.text(english.settingsPayjoinAdvancedTitle), findsOneWidget);
  });

  testWidgets('the enable switch reaches the cubit', (tester) async {
    final cubit = _cubit(enabled: false);
    await _pump(tester, cubit);

    tester.widget<BBSwitch>(find.byType(BBSwitch)).onChanged!(true);
    await tester.pumpAndSettle();

    verify(
      () => cubit.togglePayjoinEnabled(
        true,
        requestConsent: any(named: 'requestConsent'),
      ),
    ).called(1);
  });

  testWidgets('the advanced row opens the advanced settings route', (
    tester,
  ) async {
    await _pump(tester, _cubit(enabled: true));

    await tester.tap(find.text(english.settingsPayjoinAdvancedTitle));
    await tester.pumpAndSettle();

    expect(find.text('advanced payjoin settings'), findsOneWidget);
  });
}

_MockSettingsCubit _cubit({required bool enabled}) {
  final cubit = _MockSettingsCubit();
  when(() => cubit.state).thenReturn(
    SettingsState(
      payjoinPolicy: PayjoinPolicy.defaults().copyWith(enabled: enabled),
    ),
  );
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(
    () => cubit.togglePayjoinEnabled(
      any(),
      requestConsent: any(named: 'requestConsent'),
    ),
  ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(true));
  return cubit;
}

Future<void> _pump(WidgetTester tester, SettingsCubit cubit) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: const PayjoinSettingsScreen(),
        ),
      ),
      GoRoute(
        name: SettingsRoute.payjoinAdvancedSettings.name,
        path: '/payjoin-advanced',
        builder: (context, state) =>
            const Scaffold(body: Text('advanced payjoin settings')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
}
