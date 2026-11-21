import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_secret_references_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:secrets/secrets.dart';

import 'dart:async';

import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_network_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/load_network_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _WalletBloc extends Mock implements WalletBloc {}

class _PriceBloc extends Mock implements BitcoinPriceBloc {}

class _Settings extends Mock implements SettingsRepository {}

class _References extends Mock implements WalletSecretReferencesRepository {}

class _Defaults extends Mock implements CreateDefaultWalletsUsecase {}

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
  testWidgets('pushing Receive never requests a sync; returning home does', (
    tester,
  ) async {
    final wallet = _WalletBloc();
    final price = _PriceBloc();
    when(() => wallet.state)
        .thenReturn(const WalletState(failure: NoWalletsFoundFailure()));
    when(() => wallet.stream)
        .thenAnswer((_) => const Stream<WalletState>.empty());
    when(() => price.state)
        .thenReturn(const BitcoinPriceState(loadingPrice: true));
    when(() => price.stream)
        .thenAnswer((_) => const Stream<BitcoinPriceState>.empty());
    final settings = _Settings();
    when(settings.readDeveloperEnvironment)
        .thenAnswer((_) => Completer<DeveloperEnvironmentPreferences>().future);
    final references = _References();
    NetworkWalletSetupCubit createSetupCubit() => NetworkWalletSetupCubit(
      LoadNetworkWalletSetupUsecase(settings, references),
      CreateNetworkWalletUsecase(
        settings,
        references,
        Secrets(scratchDirectory: () async => '/tmp'),
        _Defaults(),
      ),
    );
    final quickActions = createQuickActionsCubit(
      storage: _MemoryQuickActionsStorage(),
      warning: (_) {},
      exchangeVisible: Stream.value(false),
    );
    addTearDown(quickActions.close);
    final router = GoRouter(
      initialLocation: '/wallet',
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/wallet',
              builder: (_, _) => WalletHomeScreen(
                arkHost: null,
                createSetupCubit: createSetupCubit,
                onEmptyMainnet: () {},
                onImportNetworkWallet: () {},
                onRecoverEncryptedVault: () {},
                quickActions: quickActions,
                onQuickAction: (_, _) {},
                onCustomizeQuickActions: (_) {},
              ),
            ),
          ],
        ),
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/receive/bitcoin',
              builder: (_, _) => const Text('Receive'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<WalletBloc>.value(value: wallet),
          BlocProvider<BitcoinPriceBloc>.value(value: price),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    verify(() => wallet.add(const WalletRefreshed())).called(1);
    clearInteractions(wallet);
    unawaited(router.push<void>('/receive/bitcoin'));
    await tester.pumpAndSettle();
    expect(find.text('Receive'), findsOneWidget);
    verifyNever(() => wallet.add(const WalletRefreshed()));
    router.pop();
    await tester.pumpAndSettle();
    verify(() => wallet.add(const WalletRefreshed())).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
