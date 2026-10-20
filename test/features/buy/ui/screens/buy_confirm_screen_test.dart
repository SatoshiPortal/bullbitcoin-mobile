import 'package:flutter/rendering.dart';
import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_confirm_screen.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_input_screen.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullCountdown, BullShimmerLine;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuyBloc extends Mock implements BuyBloc {}

class _MockExchangeCubit extends Mock implements ExchangeCubit {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBuyOrder extends Mock implements BuyOrder {}

void main() {
  setUpAll(() => registerFallbackValue(const BuyEvent.confirmOrder()));

  Future<({BuyBloc bloc, void Function(BuyState) update})> pumpScreen(
    WidgetTester tester,
    BuyState initial, {
    double textScale = 1,
  }) async {
    final bloc = _MockBuyBloc();
    final settings = _MockSettingsCubit();
    final states = StreamController<BuyState>.broadcast();
    addTearDown(states.close);
    var state = initial;
    when(() => bloc.state).thenAnswer((_) => state);
    when(() => bloc.stream).thenAnswer((_) => states.stream);
    when(() => settings.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    when(() => settings.stream).thenAnswer((_) => const Stream.empty());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BuyBloc>.value(value: bloc),
            BlocProvider<SettingsCubit>.value(value: settings),
          ],
          child: const BuyConfirmScreen(),
        ),
      ),
    );
    await tester.pump();
    return (
      bloc: bloc,
      update: (next) {
        state = next;
        states.add(next);
      },
    );
  }

  testWidgets('pending order uses skeletons, then shows the API quote', (
    tester,
  ) async {
    final screen = await pumpScreen(
      tester,
      const BuyState(isCreatingOrder: true),
    );
    expect(find.byType(BullShimmerLine), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(BullCountdown), findsNothing);
    expect(tester.widget<BullButton>(find.byType(BullButton)).disabled, isTrue);
    await tester.tap(find.byType(BullButton));
    verifyNever(() => screen.bloc.add(any()));

    final order = _MockBuyOrder();
    when(() => order.orderId).thenReturn('order-1');
    when(() => order.payinAmount).thenReturn(100);
    when(() => order.payinCurrency).thenReturn('CAD');
    when(() => order.payoutAmount).thenReturn(0.0005);
    when(() => order.exchangeRateAmount).thenReturn(200000);
    when(() => order.exchangeRateCurrency).thenReturn('CAD');
    when(() => order.isLiquid).thenReturn(false);
    when(
      () => order.confirmationDeadline,
    ).thenReturn(DateTime.now().add(const Duration(minutes: 5)));
    screen.update(BuyState(buyOrder: order));
    await tester.pump();

    expect(find.byType(BullShimmerLine), findsNothing);
    expect(find.text('50,000 sats'), findsOneWidget);
    expect(find.text('100.00 CAD'), findsWidgets);
    expect(find.byType(BullCountdown), findsOneWidget);
    expect(
      tester.widget<BullButton>(find.byType(BullButton)).disabled,
      isFalse,
    );
    await tester.tap(find.byType(BullButton));
    verify(() => screen.bloc.add(const BuyEvent.confirmOrder())).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an expired quote asks for one refresh, not one per refresh', (
    tester,
  ) async {
    final order = _MockBuyOrder();
    when(() => order.orderId).thenReturn('order-1');
    when(() => order.payinAmount).thenReturn(100);
    when(() => order.payinCurrency).thenReturn('CAD');
    when(() => order.payoutAmount).thenReturn(0.0005);
    when(() => order.exchangeRateAmount).thenReturn(200000);
    when(() => order.exchangeRateCurrency).thenReturn('CAD');
    when(() => order.isLiquid).thenReturn(false);
    when(() => order.isPayinCompleted).thenReturn(false);
    when(
      () => order.confirmationDeadline,
    ).thenReturn(DateTime.now().subtract(const Duration(minutes: 1)));
    final screen = await pumpScreen(tester, BuyState(buyOrder: order));

    // Each refresh flips the loading flag on and off. The quote stays expired,
    // so nothing new is learned and nothing may trigger another request: this
    // loop ran at HTTP speed under a covered success screen and drew 429s.
    // The mocked bloc delivers each state on the next frame, hence two pumps.
    for (var i = 0; i < 3; i++) {
      screen.update(BuyState(buyOrder: order, isRefreshingOrder: true));
      await tester.pump();
      await tester.pump();
      screen.update(BuyState(buyOrder: order));
      await tester.pump();
      await tester.pump();
    }

    verify(() => screen.bloc.add(const BuyEvent.refreshOrder())).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'creation failure stops the skeletons and keeps purchase disabled',
    (tester) async {
      final screen = await pumpScreen(
        tester,
        const BuyState(isCreatingOrder: true),
      );
      screen.update(
        const BuyState(failure: BuyUnexpectedFailure('private diagnostic')),
      );
      await tester.pump();

      expect(find.byType(BullShimmerLine), findsNothing);
      expect(find.byType(BullCountdown), findsNothing);
      expect(find.text('—'), findsNWidgets(4));
      expect(
        find.text(
          'Your order could not be created right now. Please try again or contact support.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('private diagnostic'), findsNothing);
      expect(
        tester.widget<BullButton>(find.byType(BullButton)).disabled,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Continue opens confirmation before a quote and returning does not navigate again',
    (tester) async {
      const user = UserSummary(
        userNumber: 1,
        groups: ['KYC_IDENTITY_VERIFIED'],
        profile: UserProfile(firstName: 'Test', lastName: 'User'),
        email: 'test@example.com',
        balances: [],
        dca: UserDca(isActive: false),
        autoBuy: UserAutoBuy(
          isActive: false,
          addresses: UserAutoBuyAddresses(),
        ),
      );
      final bloc = _MockBuyBloc();
      final settings = _MockSettingsCubit();
      final exchange = _MockExchangeCubit();
      final states = StreamController<BuyState>.broadcast();
      addTearDown(states.close);
      var state = const BuyState(
        isStarted: true,
        userSummary: user,
        amountInput: '100',
        currencyInput: 'CAD',
        exchangeRate: 100000,
        balances: {'CAD': 1000},
        bitcoinAddressInput: 'tb1qtest',
      );
      void update(BuyState next) {
        state = next;
        states.add(next);
      }

      when(() => bloc.state).thenAnswer((_) => state);
      when(() => bloc.stream).thenAnswer((_) => states.stream);
      when(() => bloc.close()).thenAnswer((_) async {});
      when(() => bloc.add(const BuyEvent.createOrder())).thenAnswer((_) {
        update(state.copyWith(isCreatingOrder: true));
      });
      when(() => bloc.add(const BuyEvent.orderCreationAbandoned())).thenAnswer((
        _,
      ) {
        update(
          state.copyWith(isCreatingOrder: false, buyOrder: null, failure: null),
        );
      });
      when(() => settings.state).thenReturn(
        const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      when(
        () => exchange.state,
      ).thenReturn(const ExchangeState(userSummary: user));
      when(() => exchange.stream).thenAnswer((_) => const Stream.empty());
      locator.pushNewScope(
        init: (scope) => scope.registerFactory<BuyBloc>(() => bloc),
      );
      addTearDown(locator.popScope);
      final router = GoRouter(
        initialLocation: '/buy',
        routes: BuyRouter.routes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: settings),
            BlocProvider<ExchangeCubit>.value(value: exchange),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is BullButton && w.label == 'Continue'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BuyConfirmScreen), findsOneWidget);
      expect(find.byType(BullShimmerLine), findsWidgets);
      expect(state.buyOrder, isNull);
      expect(
        tester
            .widget<BullButton>(
              find.descendant(
                of: find.byType(BuyConfirmScreen),
                matching: find.byType(BullButton),
              ),
            )
            .disabled,
        isTrue,
      );

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      verify(() => bloc.add(const BuyEvent.orderCreationAbandoned())).called(1);
      expect(find.byType(BuyInputScreen), findsOneWidget);
      expect(find.byType(BuyConfirmScreen), findsNothing);
      // The result cannot itself open confirmation: only starting creation does.
      final order = _MockBuyOrder();
      when(() => order.orderId).thenReturn('order-1');
      update(state.copyWith(buyOrder: order));
      await tester.pump();
      expect(find.byType(BuyConfirmScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'headline expands for large text instead of clipping the amount',
    (tester) async {
      final order = _MockBuyOrder();
      when(() => order.orderId).thenReturn('order-1');
      when(() => order.payinAmount).thenReturn(100);
      when(() => order.payinCurrency).thenReturn('CAD');
      when(() => order.payoutAmount).thenReturn(0.0005);
      when(() => order.exchangeRateAmount).thenReturn(200000);
      when(() => order.exchangeRateCurrency).thenReturn('CAD');
      when(() => order.isLiquid).thenReturn(false);
      when(() => order.confirmationDeadline).thenReturn(null);
      await pumpScreen(tester, BuyState(buyOrder: order), textScale: 2);
      final text = tester.renderObject<RenderParagraph>(
        find.text('100.00 CAD').first,
      );
      expect(
        text.size.height,
        greaterThanOrEqualTo(text.getMaxIntrinsicHeight(text.size.width)),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
