import 'dart:async';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _WalletBloc extends Mock implements WalletBloc {}

class _PriceBloc extends Mock implements BitcoinPriceBloc {}

class _ChartCubit extends Mock implements PriceChartCubit {}

class _SettingsCubit extends Mock implements SettingsCubit {}

class _AnnouncementsCubit extends Mock implements AnnouncementsCubit {}

void main() {
  for (final refreshingOnMount in [true, false]) {
    testWidgets(
      'follows ${refreshingOnMount ? 'mounted' : 'new'} refresh, then accepts a pull',
      (tester) async {
        final wallet = _WalletBloc();
        final price = _PriceBloc();
        final chart = _ChartCubit();
        final settings = _SettingsCubit();
        final announcements = _AnnouncementsCubit();
        final states = StreamController<WalletState>.broadcast();
        var state = WalletState(
          status: WalletStatus.success,
          isRefreshing: refreshingOnMount,
        );
        when(() => wallet.state).thenAnswer((_) => state);
        when(() => wallet.stream).thenAnswer((_) => states.stream);
        when(() => wallet.refresh()).thenAnswer((_) async {});
        when(() => price.state).thenReturn(
          const BitcoinPriceState(currency: 'CAD', bitcoinPrice: 50000),
        );
        when(() => price.stream).thenAnswer((_) => const Stream.empty());
        when(() => chart.state).thenReturn(const PriceChartState());
        when(() => chart.stream).thenAnswer((_) => const Stream.empty());
        when(() => settings.state).thenReturn(
          SettingsState(
            storedSettings: SettingsEntity(
              environment: Environment.mainnet,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
            ),
          ),
        );
        when(() => settings.stream).thenAnswer((_) => const Stream.empty());
        when(() => announcements.state).thenReturn(const AnnouncementsState());
        when(
          () => announcements.stream,
        ).thenAnswer((_) => const Stream.empty());
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => MultiBlocProvider(
                providers: [
                  BlocProvider<WalletBloc>.value(value: wallet),
                  BlocProvider<BitcoinPriceBloc>.value(value: price),
                  BlocProvider<PriceChartCubit>.value(value: chart),
                  BlocProvider<SettingsCubit>.value(value: settings),
                  BlocProvider<AnnouncementsCubit>.value(value: announcements),
                ],
                child: const Scaffold(body: WalletHomeScreen()),
              ),
            ),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await states.close();
          router.dispose();
        });
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        if (!refreshingOnMount) {
          await tester.pumpAndSettle();
          state = state.copyWith(isRefreshing: true);
          states.add(state);
          await tester.pump();
          // Run the listener's post-frame callback even with empty wallets.
          tester.binding.scheduleFrame();
        }
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        verifyNever(() => wallet.refresh());
        verifyNever(() => price.add(const BitcoinPriceFetched()));
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);

        state = state.copyWith(isRefreshing: false);
        states.add(state);
        await tester.pumpAndSettle();
        expect(find.byType(RefreshProgressIndicator), findsNothing);

        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, 400),
          1000,
        );
        await tester.pumpAndSettle();
        verify(() => wallet.refresh()).called(1);
        verify(() => price.add(const BitcoinPriceFetched())).called(1);
      },
    );
  }
}
