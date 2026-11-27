import 'package:preferences/preferences.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart';

import 'dart:async';

import 'package:bitcoin_price/testing.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _WalletBloc extends Mock implements WalletBloc {}

class _Settings extends Mock implements Preferences {}

class _References extends Mock implements WalletInventory {}

class _Defaults extends Mock implements DefaultWalletProvisioning {}

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

    when(() => wallet.state)
        .thenReturn(const WalletState(failure: NoWalletsFoundFailure()));
    when(() => wallet.stream)
        .thenAnswer((_) => const Stream<WalletState>.empty());

    final settings = _Settings();
    when(settings.readDeveloperEnvironment).thenAnswer(
      (_) => (Completer<DeveloperEnvironmentPreferences>().future).then(
        (value) => Ok(value),
      ),
    );
    final references = _References();
    NetworkWalletProvisioning provisioning() => NetworkWalletProvisioning(
      settings: settings,
      inventory: references,
      defaults: _Defaults(),
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
                announcements: const SizedBox.shrink(),
                arkHost: null,
                networkWalletProvisioning: provisioning,
                onEmptyMainnet: () {},
                onImportNetworkWallet: () {},
                onRecoverEncryptedVault: () {},
                quickActions: quickActions,
                onQuickAction: (_, _) {},
                onCustomizeQuickActions: (_) {},
                exchangePrompt: createExchangePromptCubit(
                  storage: _MemoryQuickActionsStorage(),
                  warning: (_) {},
                  offered: const Stream.empty(),
                ),
                onActivateExchange: (_) {},
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
          BitcoinPriceFixture.prices(loadingPrice: true),
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
