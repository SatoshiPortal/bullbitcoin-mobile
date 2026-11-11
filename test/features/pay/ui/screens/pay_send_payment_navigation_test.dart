import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_send_payment_screen.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';

class _MockPayBloc extends Mock implements PayBloc {}

void main() {
  setUpAll(
    () => registerFallbackValue(const PayEvent.paymentPreparationAbandoned()),
  );
  const summary = UserSummary(
    userNumber: 1,
    groups: ['KYC_IDENTITY_VERIFIED'],
    profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
    email: 'sat@example.com',
    balances: [],
    dca: UserDca(isActive: false),
    autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
  );

  Future<({GoRouter router, PayBloc bloc})> pump(
    WidgetTester tester, {
    required bool broadcast,
    required bool late,
  }) async {
    final bloc = _MockPayBloc();
    final order = FiatPaymentOrder(
      orderId: 'paid-order',
      orderType: OrderType.fiatPayment,
      message: OrderMessage(code: '', message: ''),
      orderNumber: 1,
      payinAmount: 0.001,
      payinCurrency: 'BTC',
      payoutAmount: 100,
      payoutCurrency: 'CAD',
      payinMethod: OrderPaymentMethod.bitcoin,
      payoutMethod: OrderPaymentMethod.cadBalance,
      orderStatus: late ? OrderStatus.expired : OrderStatus.inProgress,
      payinStatus: OrderPayinStatus.awaitingPayment,
      payoutStatus: OrderPayoutStatus.notStarted,
      createdAt: DateTime.now(),
      confirmationDeadline: DateTime.now().add(const Duration(minutes: 5)),
      bitcoinAddress: 'tb1qaddress',
      isTestnet: true,
    );
    final state = PayState.payment(
      userSummary: summary,
      selectedRecipient: const RecipientViewModel(
        id: 'recipient',
        type: RecipientType.interacEmailCad,
        email: 'recipient@example.com',
      ),
      amount: const FiatAmount(100),
      payOrder: order,
      payinBroadcastTxid: broadcast ? 'paid-transaction' : null,
      isPayinPastDeadline: late,
      isConfirmingPayment: broadcast && !late,
    );
    when(() => bloc.state).thenReturn(state);
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    final router = GoRouter(
      initialLocation: '/flow/payment',
      routes: [
        GoRoute(
          name: ExchangeRoute.exchangeHome.name,
          path: ExchangeRoute.exchangeHome.path,
          builder: (_, _) => const Scaffold(body: Text('destination home')),
        ),
        GoRoute(
          path: '/flow',
          builder: (_, _) => const Scaffold(body: Text('wallet selection')),
          routes: [
            GoRoute(
              path: 'payment',
              builder: (_, _) => BlocProvider<PayBloc>.value(
                value: bloc,
                child: const PaySendPaymentScreen(),
              ),
            ),
          ],
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return (router: router, bloc: bloc);
  }

  for (final systemBack in [false, true]) {
    testWidgets(
      'a late payin leaves the entire flow via ${systemBack ? 'Back' : 'Leave'}',
      (tester) async {
        final screen = await pump(tester, broadcast: true, late: true);
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.text('Leave'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          screen.router.routerDelegate.currentConfiguration.uri.path,
          ExchangeRoute.exchangeHome.path,
        );
        expect(find.text('destination home'), findsOneWidget);
        verifyNever(
          () => screen.bloc.add(const PayEvent.paymentPreparationAbandoned()),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('a broadcast payin still blocks Back before late status', (
    tester,
  ) async {
    final screen = await pump(tester, broadcast: true, late: false);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
      screen.router.routerDelegate.currentConfiguration.uri.path,
      '/flow/payment',
    );
    verifyNever(
      () => screen.bloc.add(const PayEvent.paymentPreparationAbandoned()),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Back before broadcasting pops normally and abandons preparation',
    (tester) async {
      final screen = await pump(tester, broadcast: false, late: false);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        screen.router.routerDelegate.currentConfiguration.uri.path,
        '/flow',
      );
      verify(
        () => screen.bloc.add(const PayEvent.paymentPreparationAbandoned()),
      ).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
