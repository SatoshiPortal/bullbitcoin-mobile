import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'dart:async';

import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _WalletBloc extends Mock implements WalletBloc {}

class _PriceBloc extends Mock implements BitcoinPriceBloc {}

class _Settings extends Mock implements SettingsCubit {}

class _Chart extends Mock implements PriceChartCubit {}

class _Announcements extends Mock implements AnnouncementsCubit {}

void main() {
  testWidgets('pushing Receive never requests a sync; returning home does', (
    tester,
  ) async {
    final wallet = _WalletBloc();
    final price = _PriceBloc();
    when(
      () => wallet.state,
    ).thenReturn(const WalletState(status: WalletStatus.success));
    when(
      () => wallet.stream,
    ).thenAnswer((_) => const Stream<WalletState>.empty());
    when(() => price.state).thenReturn(
      const BitcoinPriceState(currency: 'USD', bitcoinPrice: 100000),
    );
    when(
      () => price.stream,
    ).thenAnswer((_) => const Stream<BitcoinPriceState>.empty());
    final settings = _Settings();
    when(() => settings.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    when(
      () => settings.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    final chart = _Chart();
    when(() => chart.state).thenReturn(const PriceChartState());
    when(
      () => chart.stream,
    ).thenAnswer((_) => const Stream<PriceChartState>.empty());
    final announcements = _Announcements();
    when(() => announcements.state).thenReturn(const AnnouncementsState());
    when(
      () => announcements.stream,
    ).thenAnswer((_) => const Stream<AnnouncementsState>.empty());
    final router = GoRouter(
      initialLocation: '/wallet',
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/wallet',
              builder: (_, _) => const WalletHomeScreen(),
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
          BlocProvider<SettingsCubit>.value(value: settings),
          BlocProvider<PriceChartCubit>.value(value: chart),
          BlocProvider<AnnouncementsCubit>.value(value: announcements),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
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
