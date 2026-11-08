import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_success_screen.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuyBloc extends Mock implements BuyBloc {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBuyOrder extends Mock implements BuyOrder {}

void main() {
  testWidgets('view details opens the transaction order details route', (
    tester,
  ) async {
    final buyBloc = _MockBuyBloc();
    final settingsCubit = _MockSettingsCubit();
    final order = _MockBuyOrder();
    when(() => buyBloc.state).thenReturn(BuyState(buyOrder: order));
    when(
      () => buyBloc.stream,
    ).thenAnswer((_) => const Stream<BuyState>.empty());
    when(() => settingsCubit.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => order.orderId).thenReturn('order-42');
    when(() => order.payoutAmount).thenReturn(0.001);
    when(() => order.payinAmount).thenReturn(100.0);
    when(() => order.payinCurrency).thenReturn('CAD');
    when(() => order.bitcoinAddress).thenReturn(null);
    when(() => order.transactionId).thenReturn(null);
    when(() => order.scheduledPayoutTime).thenReturn(null);
    when(() => order.payjoinOutcome).thenReturn(OrderPayjoinOutcome.none);

    final router = GoRouter(
      initialLocation: '/buy/success',
      routes: [
        GoRoute(
          path: '/buy/success',
          name: BuyRoute.buySuccess.name,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<BuyBloc>.value(value: buyBloc),
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
            ],
            child: const BuySuccessScreen(),
          ),
        ),
        GoRoute(
          path: '/transaction/order/:orderId',
          name: TransactionsRoute.orderTransactionDetails.name,
          builder: (context, state) => Text(state.pathParameters['orderId']!),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();

    expect(find.text('order-42'), findsOneWidget);
  });

  group('payout payjoin', () {
    late _MockBuyBloc buyBloc;
    late _MockBuyOrder order;

    setUpAll(() => registerFallbackValue(const BuyEvent.refreshOrder()));

    Future<void> pumpSuccess(
      WidgetTester tester, {
      required Duration age,
    }) async {
      buyBloc = _MockBuyBloc();
      final settingsCubit = _MockSettingsCubit();
      order = _MockBuyOrder();
      when(() => buyBloc.state).thenReturn(BuyState(buyOrder: order));
      when(
        () => buyBloc.stream,
      ).thenAnswer((_) => const Stream<BuyState>.empty());
      when(() => settingsCubit.state).thenReturn(
        const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      when(
        () => settingsCubit.stream,
      ).thenAnswer((_) => const Stream<SettingsState>.empty());
      when(() => order.orderId).thenReturn('order-42');
      when(() => order.payoutAmount).thenReturn(0.0001);
      when(() => order.payinAmount).thenReturn(10.0);
      when(() => order.payinCurrency).thenReturn('USD');
      when(() => order.bitcoinAddress).thenReturn(null);
      when(() => order.transactionId).thenReturn(null);
      when(() => order.scheduledPayoutTime).thenReturn(null);
      when(
        () => order.payjoinOutcome,
      ).thenReturn(OrderPayjoinOutcome.inProgress);
      when(() => order.createdAt).thenReturn(DateTime.now().subtract(age));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<BuyBloc>.value(value: buyBloc),
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
            ],
            child: const BuySuccessScreen(),
          ),
        ),
      );
    }

    testWidgets('is followed while the exchange may still settle it', (
      tester,
    ) async {
      await pumpSuccess(tester, age: Duration.zero);

      expect(find.text('Payjoin in progress'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      verify(() => buyBloc.add(const BuyEvent.refreshOrder())).called(2);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    // The exchange stops negotiating five minutes after creating the order and
    // may report nothing until its ordinary payout goes out.
    testWidgets('is no longer claimed nor read once its window has passed', (
      tester,
    ) async {
      await pumpSuccess(tester, age: const Duration(minutes: 7));

      expect(find.text('Payjoin in progress'), findsNothing);
      await tester.pump(const Duration(minutes: 5));
      verifyNever(() => buyBloc.add(any()));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('stops being read when its window closes on screen', (
      tester,
    ) async {
      await pumpSuccess(tester, age: const Duration(minutes: 5, seconds: 50));
      expect(find.text('Payjoin in progress'), findsOneWidget);

      // Fake time does not move the wall clock: age the order instead.
      when(() => order.createdAt).thenReturn(
        DateTime.now().subtract(const Duration(minutes: 6, seconds: 1)),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('Payjoin in progress'), findsNothing);

      clearInteractions(buyBloc);
      await tester.pump(const Duration(minutes: 5));
      verifyNever(() => buyBloc.add(any()));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
