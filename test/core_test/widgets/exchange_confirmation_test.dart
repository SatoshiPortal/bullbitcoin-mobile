import 'dart:async';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_send_payment_screen.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_send_payment_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SellBloc extends Mock implements SellBloc {}

class _PayBloc extends Mock implements PayBloc {}

class _Wallet extends Mock implements Wallet {}

class _SellOrder extends Mock implements SellOrder {}

class _PayOrder extends Mock implements FiatPaymentOrder {}

void main() {
  for (final sell in [true, false]) {
    testWidgets(
      '${sell ? 'sell' : 'pay'} preparation, error, ready and sending',
      (tester) async {
        final wallet = _Wallet();
        when(() => wallet.label).thenReturn('Test wallet');
        when(() => wallet.isDefault).thenReturn(false);
        when(() => wallet.isLiquid).thenReturn(false);
        const summary = UserSummary(
          userNumber: 1,
          groups: [],
          profile: UserProfile(firstName: 'Test', lastName: 'User'),
          email: 'test@example.com',
          balances: [],
          dca: UserDca(isActive: false),
          autoBuy: UserAutoBuy(
            isActive: false,
            addresses: UserAutoBuyAddresses(),
          ),
        );
        const recipient = RecipientViewModel(
          id: 'test-recipient',
          type: RecipientType.interacEmailCad,
          email: 'test@example.com',
        );
        final sellInput = SellWalletSelectionState(
          userSummary: summary,
          bitcoinUnit: BitcoinUnit.sats,
          orderAmount: const FiatAmount(50),
          fiatCurrency: FiatCurrency.cad,
        );
        final payInput = PayWalletSelectionState(
          selectedRecipient: recipient,
          userSummary: summary,
          amount: const FiatAmount(50),
        );
        final sellBloc = _SellBloc();
        final payBloc = _PayBloc();
        final sellStates = StreamController<SellState>.broadcast();
        final payStates = StreamController<PayState>.broadcast();
        addTearDown(sellStates.close);
        addTearDown(payStates.close);
        SellState sellState = SellPreparingPaymentState(
          input: sellInput,
          selectedWallet: wallet,
        );
        PayState payState = PayPreparingPaymentState(
          input: payInput,
          selectedWallet: wallet,
        );
        when(() => sellBloc.state).thenAnswer((_) => sellState);
        when(() => sellBloc.stream).thenAnswer((_) => sellStates.stream);
        when(() => payBloc.state).thenAnswer((_) => payState);
        when(() => payBloc.stream).thenAnswer((_) => payStates.stream);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<SellBloc>.value(value: sellBloc),
                BlocProvider<PayBloc>.value(value: payBloc),
              ],
              child: sell
                  ? const SellSendPaymentScreen()
                  : const PaySendPaymentScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(BullShimmerLine), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(BullFadingLinearProgress), findsNothing);
        expect(
          tester.widget<BBButton>(find.byType(BBButton).last).disabled,
          isTrue,
        );

        sellState = SellPreparingPaymentState(
          input: sellInput,
          selectedWallet: wallet,
          error: const SellUnexpectedFailure('private diagnostic'),
        );
        payState = PayPreparingPaymentState(
          input: payInput,
          selectedWallet: wallet,
          error: const PayUnexpectedFailure('private diagnostic'),
        );
        sellStates.add(sellState);
        payStates.add(payState);
        await tester.pump();
        expect(find.byType(BullShimmerLine), findsNothing);
        expect(find.textContaining('private diagnostic'), findsNothing);

        const address = 'bc1q0000000000000000000000000000000000000';
        final sellOrder = _SellOrder();
        final payOrder = _PayOrder();
        for (final Order order in [sellOrder, payOrder]) {
          when(() => order.orderNumber).thenReturn(123);
          when(() => order.confirmationDeadline).thenReturn(null);
          when(() => order.toAddress).thenReturn(address);
          when(() => order.payinAmount).thenReturn(0.001);
          when(() => order.payoutAmount).thenReturn(50);
          when(() => order.payoutCurrency).thenReturn('CAD');
        }
        when(() => sellOrder.exchangeRateAmount).thenReturn(50000);
        when(() => sellOrder.exchangeRateCurrency).thenReturn('CAD');
        when(() => payOrder.exchangeRateAmount).thenReturn(50000);
        when(() => payOrder.exchangeRateCurrency).thenReturn('CAD');
        when(
          () => sellOrder.payoutMethod,
        ).thenReturn(OrderPaymentMethod.cadBalance);
        when(() => sellOrder.payjoinBip21).thenReturn(null);
        when(() => payOrder.payjoinBip21).thenReturn(null);
        when(() => payOrder.paymentDescription).thenReturn(null);
        final readySell = SellPaymentState(
          userSummary: summary,
          bitcoinUnit: BitcoinUnit.sats,
          orderAmount: const FiatAmount(50),
          fiatCurrency: FiatCurrency.cad,
          selectedWallet: wallet,
          sellOrder: sellOrder,
          absoluteFees: 100,
        );
        final readyPay = PayPaymentState(
          selectedRecipient: recipient,
          userSummary: summary,
          amount: const FiatAmount(50),
          selectedWallet: wallet,
          payOrder: payOrder,
          absoluteFees: 100,
        );
        sellState = readySell;
        payState = readyPay;
        sellStates.add(sellState);
        payStates.add(payState);
        await tester.pump();
        expect(find.byType(AddressViewer), findsOneWidget);
        expect(
          tester.widget<AddressViewer>(find.byType(AddressViewer)).data,
          address,
        );
        final action = find.byType(BBButton).last;
        expect(tester.widget<BBButton>(action).disabled, isFalse);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.bottomNavigationBar, isNotNull);
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(600));

        sellState = readySell.copyWith(isConfirmingPayment: true);
        payState = readyPay.copyWith(isConfirmingPayment: true);
        sellStates.add(sellState);
        payStates.add(payState);
        await tester.pump();
        expect(find.byType(BBButton), findsNothing);
        expect(find.byType(BullAsyncStatus), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(BullFadingLinearProgress), findsOneWidget);
        expect(find.byType(BullShimmerLine), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
