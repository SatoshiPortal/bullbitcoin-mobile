import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _WalletBloc extends Mock implements WalletBloc {}

class _SettingsCubit extends Mock implements SettingsCubit {}

Wallet _wallet(String id, String label) => Wallet(
  origin: id,
  label: label,
  network: Network.bitcoinMainnet,
  scriptType: null,
  signers: const [],
  publicDescriptor: 'descriptor-$id',
  balanceSat: BigInt.zero,
);

void main() {
  testWidgets('Settings lists wallets and opens the selected wallet details', (
    tester,
  ) async {
    final wallets = _WalletBloc();
    final settings = _SettingsCubit();
    final changes = StreamController<WalletState>.broadcast();
    addTearDown(changes.close);
    var state = WalletState(
      status: WalletStatus.success,
      wallets: [_wallet('savings', 'Savings')],
    );
    when(() => wallets.state).thenAnswer((_) => state);
    when(() => wallets.stream).thenAnswer((_) => changes.stream);
    when(() => settings.state).thenReturn(const SettingsState());
    when(() => settings.stream).thenAnswer((_) => const Stream.empty());
    final routes = SettingsRouter.route().routes.whereType<GoRoute>();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const WalletSettingsScreen(),
          routes: [
            ...routes.where((route) => route.name == 'walletDetailsWalletList'),
            GoRoute(
              name: SettingsRoute.walletDetailsSelectedWallet.name,
              path: SettingsRoute.walletDetailsSelectedWallet.path,
              builder: (_, state) => Scaffold(
                body: Text(
                  'Selected wallet: ${state.pathParameters['walletId']}',
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<WalletBloc>.value(value: wallets),
          BlocProvider<SettingsCubit>.value(value: settings),
        ],
        child: MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wallets'), findsOneWidget);
    await tester.tap(find.text('Wallets'));
    await tester.pumpAndSettle();
    expect(find.text('Savings'), findsOneWidget);

    state = state.copyWith(
      wallets: [...state.wallets, _wallet('vault', 'Practice BullVault')],
    );
    changes.add(state);
    await tester.pumpAndSettle();
    expect(find.text('Practice BullVault'), findsOneWidget);
    await tester.tap(find.text('Practice BullVault'));
    await tester.pumpAndSettle();
    expect(find.text('Selected wallet: vault'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('Practice BullVault'), findsOneWidget);
  });
}
