import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_secret_references_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_network_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/load_network_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';

class _Settings extends Mock implements Preferences {}

class _References extends Mock implements WalletSecretReferencesRepository {}

class _Defaults extends Mock implements CreateDefaultWalletsUsecase {}

class _WalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _PriceBloc extends MockBloc<BitcoinPriceEvent, BitcoinPriceState>
    implements BitcoinPriceBloc {}

class _MemoryQuickActionsStorage implements QuickActionsStorage {
  String? value;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async => this.value = value;

  @override
  Future<void> remove(String key) async => value = null;
}

void main() {
  for (final environment in Environment.values) {
    testWidgets('empty ${environment.name} keeps its recovery destinations', (
      tester,
    ) async {
      final temporary = Directory.systemTemp.createTempSync(
        'bull_empty_recovery_',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      final settings = _Settings();
      when(settings.readDeveloperEnvironment).thenAnswer(
        (_) async => Ok((
          environment: environment,
          isSuperuser: true,
          isDevModeEnabled: true,
        )),
      );
      final references = _References();
      final defaults = _Defaults();
      NetworkWalletSetupCubit createSetupCubit() => NetworkWalletSetupCubit(
        LoadNetworkWalletSetupUsecase(settings, references),
        CreateNetworkWalletUsecase(
          settings,
          references,
          Secrets(scratchDirectory: () async => '${temporary.path}/scratch'),
          defaults,
        ),
      );
      final wallets = _WalletBloc();
      whenListen(
        wallets,
        const Stream<WalletState>.empty(),
        initialState: const WalletState(failure: NoWalletsFoundFailure()),
      );
      final price = _PriceBloc();
      whenListen(
        price,
        const Stream<BitcoinPriceState>.empty(),
        initialState: const BitcoinPriceState(loadingPrice: true),
      );
      final quickActions = createQuickActionsCubit(
        storage: _MemoryQuickActionsStorage(),
        warning: (_) {},
        exchangeVisible: Stream.value(false),
      );
      addTearDown(quickActions.close);
      Object? recoveryRequest;
      final router = GoRouter(
        initialLocation: WalletRoute.walletHome.path,
        routes: [
          ShellRoute(
            builder: (_, _, child) => Scaffold(body: child),
            routes: [
              WalletRouter.walletHomeRoute(
                arkHost: null,
                quickActions: quickActions,
                onQuickAction: (_, _) {},
                onCustomizeQuickActions: (_) {},
                createSetupCubit: createSetupCubit,
              ),
            ],
          ),
          GoRoute(
            name: OnboardingRoute.onboarding.name,
            path: OnboardingRoute.onboarding.path,
            builder: (_, _) => const Scaffold(body: Text('Onboarding target')),
          ),
          GoRoute(
            name: OnboardingRoute.recoverFromPhysical.name,
            path: '/physical-target',
            builder: (_, _) => const Scaffold(body: Text('Physical target')),
          ),
          GoRoute(
            name: 'recoverbullFlows',
            path: '/recoverbull-flows',
            builder: (_, state) {
              final request = state.extra;
              if (request == null) {
                throw StateError('Expected encrypted recovery request');
              }
              recoveryRequest = request;
              return const Scaffold(body: Text('Encrypted recovery target'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<WalletBloc>.value(value: wallets),
            BlocProvider<BitcoinPriceBloc>.value(value: price),
          ],
          child: MaterialApp.router(
            theme: AppTheme.themeData(AppThemeType.light),
            locale: const Locale('en'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (environment == Environment.mainnet) {
        expect(find.text('Onboarding target'), findsOneWidget);
        expect(find.text('Encrypted vault'), findsNothing);
      } else {
        expect(
          find.text(environment == Environment.regtest ? 'Regtest' : 'Testnet'),
          findsOneWidget,
        );
        expect(find.text('Import Mnemonic'), findsOneWidget);
        if (environment == Environment.regtest) {
          expect(find.text('Encrypted vault'), findsOneWidget);
          await tester.tap(find.text('Encrypted vault'));
          await tester.pumpAndSettle();
          expect(find.text('Encrypted recovery target'), findsOneWidget);
          expect(recoveryRequest, isNotNull);
          router.pop();
          await tester.pumpAndSettle();
        } else {
          expect(find.text('Encrypted vault'), findsNothing);
        }
        await tester.tap(find.text('Import Mnemonic'));
        await tester.pumpAndSettle();
        expect(find.text('Physical target'), findsOneWidget);
      }
      verifyZeroInteractions(defaults);
      verifyZeroInteractions(references);
      await tester.pumpWidget(const SizedBox.shrink());
      await wallets.close();
      await price.close();
    });
  }
}
