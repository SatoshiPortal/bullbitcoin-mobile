import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_session.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_web_settings_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_auth_screen.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/settings/domain/usecases/manage_exchange_access_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/exchange_access_settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/exchange_access_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/settings_route.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/features/status_check/presentation/state.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

class _StatusCubit extends MockCubit<ServiceStatusState>
    implements ServiceStatusCubit {}

class _ExchangeCubit extends MockCubit<ExchangeState>
    implements ExchangeCubit {}

class _Exchange extends Mock implements ExchangeFacade {}

class _Keys extends Mock implements ExchangeApiKeyRepository {}

class _WebSettings extends Mock implements GetExchangeWebSettingsUsecase {}

class _QuickActionsStorage implements QuickActionsStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> remove(String key) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final succeeds in [false, true]) {
    testWidgets(
      'settings authentication ${succeeds ? 'success clears pending and returns home' : 'cancellation returns to settings'} without duplicate navigator keys',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'wizard_pending_payload':
              '{"version":1,"exchangeAccess":false,"currency":"CAD"}',
        });
        final access = ExchangeAccessFacade();
        expect(
          await access.initialize(
            isTestnet: false,
            session: ExchangeSessionFact.anonymous,
          ),
          isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
        );
        final session = ExchangeSession(_Keys());
        final settingsCubit = _SettingsCubit();
        final statusCubit = _StatusCubit();
        final exchangeCubit = _ExchangeCubit();
        final exchange = _Exchange();
        final webSettings = _WebSettings();
        when(() => settingsCubit.state).thenReturn(const SettingsState());
        when(
          () => settingsCubit.stream,
        ).thenAnswer((_) => const Stream.empty());
        when(() => statusCubit.state).thenReturn(const ServiceStatusState());
        when(() => statusCubit.stream).thenAnswer((_) => const Stream.empty());
        when(statusCubit.checkStatus).thenAnswer((_) async {});
        when(statusCubit.close).thenAnswer((_) async {});
        when(() => exchangeCubit.state).thenReturn(const ExchangeState());
        when(
          () => exchangeCubit.stream,
        ).thenAnswer((_) => const Stream.empty());
        when(webSettings.execute).thenAnswer(
          (_) async => const Err(ExchangeAccountUnavailableFailure()),
        );
        locator.registerSingleton<QuickActionsFacade>(
          QuickActionsFacade(storage: _QuickActionsStorage(), warning: (_) {}),
        );
        locator.registerSingleton<ExchangeAccessFacade>(access);
        locator.registerSingleton<ExchangeSession>(session);
        locator.registerSingleton<GetExchangeWebSettingsUsecase>(webSettings);
        locator.registerFactory<ServiceStatusCubit>(() => statusCubit);
        locator.registerFactory<ExchangeAccessSettingsCubit>(
          () => ExchangeAccessSettingsCubit(
            WatchSettingsExchangeAccessUsecase(access),
            SetSettingsExchangeAccessUsecase(access, exchange),
          ),
        );

        // Preserve the real route ownership; replace only WalletHome's unrelated
        // visual tree so the test exercises the actual Settings/Auth routes.
        final configured = AppRouter.router.configuration.routes;
        final originalShell = configured.whereType<ShellRoute>().first;
        final shellExchangeRoutes = originalShell.routes
            .whereType<GoRoute>()
            .where(
              (route) =>
                  route.name == ExchangeRoute.exchangeHome.name ||
                  route.name == ExchangeRoute.exchangeLanding.name ||
                  route.name == ExchangeRoute.exchangeAuth.name,
            );
        final rootAuthRoutes = configured.whereType<GoRoute>().where(
          (route) => route.name == ExchangeRoute.exchangeAuth.name,
        );
        final settingsRoute = configured.whereType<GoRoute>().singleWhere(
          (route) => route.name == SettingsRoute.settings.name,
        );
        final router = GoRouter(
          initialLocation: WalletRoute.walletHome.path,
          routes: [
            ShellRoute(
              builder: (_, _, child) => Scaffold(body: child),
              routes: [
                GoRoute(
                  name: WalletRoute.walletHome.name,
                  path: WalletRoute.walletHome.path,
                  builder: (_, _) => const Text('wallet home'),
                ),
                ...shellExchangeRoutes,
              ],
            ),
            ...rootAuthRoutes,
            settingsRoute,
          ],
        );
        addTearDown(() async {
          router.dispose();
          await locator.reset();
          await access.dispose();
        });
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
              BlocProvider<ExchangeCubit>.value(value: exchangeCubit),
            ],
            child: MaterialApp.router(
              theme: AppTheme.themeData(AppThemeType.light),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        unawaited(router.pushNamed<void>(SettingsRoute.exchangeAccess.name));
        await tester.pumpAndSettle();
        expect(find.byType(ExchangeAccessSettingsScreen), findsOneWidget);
        await tester.tap(find.byType(BullSwitch));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ExchangeAuthScreen), findsOneWidget);
        expect(access.current.transition, ExchangeAccessTransition.enabling);

        if (succeeds) {
          expect(
            await access.reconcileSession(ExchangeSessionFact.authenticated),
            isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
          );
          session.publish(ExchangeSessionStatus.authenticated);
          await tester.pumpAndSettle();
          expect(find.text('wallet home'), findsOneWidget);
          final prefs = await SharedPreferences.getInstance();
          final pending =
              jsonDecode(prefs.getString('wizard_pending_payload') ?? '{}')
                  as Map<String, dynamic>;
          expect(pending.containsKey('exchangeAccess'), isFalse);
          expect(pending['currency'], 'CAD');
        } else {
          await tester.tap(
            find.descendant(
              of: find.byType(ExchangeAuthScreen),
              matching: find.byType(CloseButton),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ExchangeAccessSettingsScreen), findsOneWidget);
          expect(access.current.choice, ExchangeAccessChoice.disabled);
          expect(access.current.transition, ExchangeAccessTransition.none);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
