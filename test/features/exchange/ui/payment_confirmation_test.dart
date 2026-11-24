import '../support/payin_ui_fixture.dart';

import 'package:bull_exchange/testing.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:sync/sync.dart' show WalletKey;
import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SellBloc extends Mock implements SellBloc {}

class _PayBloc extends Mock implements PayBloc {}

class _SellOrder extends Mock implements SellOrder {}

class _PayOrder extends Mock implements FiatPaymentOrder {}

void main() {
  for (final (sell, locale) in [
    (true, const Locale('en')),
    (false, const Locale('en')),
    (false, const Locale('fr')),
  ]) {
    testWidgets(
      '${sell ? 'sell' : 'pay'} preparation, error, ready and sending (${locale.languageCode})',
      (tester) async {
        final wallet = ExchangePayinWallet(
          key: WalletKey(id: 'test-wallet', network: BitcoinNetwork.mainnet),
          balanceSat: BigInt.from(1000000),
        );
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
        final recipient = RecipientViewModel(
          Recipient.create(
            recipientId: 'test-recipient',
            userId: 'user',
            userNbr: 1,
            isArchived: false,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            details: locale.languageCode == 'fr'
                ? BankTransferCadDetails.create(
                    institutionNumber: '001',
                    transitNumber: '00001',
                    accountNumber: '0000001',
                    name: 'Test Recipient',
                  )
                : InteracEmailCadDetails.create(
                    email: 'test@example.com',
                    name: 'Test Recipient',
                  ),
          ),
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
            locale: locale,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepositoryProvider.value(
              value: payinTestUi(),
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<SellBloc>.value(value: sellBloc),
                  BlocProvider<PayBloc>.value(value: payBloc),
                ],
                child: sell
                    ? const SellSendPaymentScreen()
                    : const PaySendPaymentScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(BullShimmerLine), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(BullFadingLinearProgress), findsNothing);
        expect(
          tester.widget<BullButton>(find.byType(BullButton).last).disabled,
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
          when(() => order.payinMethod).thenReturn(OrderPaymentMethod.bitcoin);
          when(() => order.payinAmount).thenReturn(0.001);
          when(() => order.payoutAmount).thenReturn(50);
          when(() => order.payoutCurrency).thenReturn('CAD');
        }
        when(() => sellOrder.exchangeRateAmount).thenReturn(50000);
        when(() => sellOrder.exchangeRateCurrency).thenReturn('CAD');
        when(() => payOrder.exchangeRateAmount).thenReturn(50000);
        when(() => payOrder.exchangeRateCurrency).thenReturn('CAD');
        when(() => sellOrder.payoutMethod)
            .thenReturn(OrderPaymentMethod.cadBalance);
        when(() => sellOrder.bitcoinAddress).thenReturn(address);
        when(() => sellOrder.liquidAddress).thenReturn(null);
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
        if (locale.languageCode == 'fr') {
          expect(find.text('Virement bancaire'), findsOneWidget);
          expect(find.text('Bank Transfer'), findsNothing);
        }
        expect(
          tester.widget<AddressViewer>(find.byType(AddressViewer)).data,
          address,
        );
        final action = find.byType(BullButton).last;
        expect(tester.widget<BullButton>(action).disabled, isFalse);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.bottomNavigationBar, isNotNull);
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(600));

        sellState = readySell.copyWith(isConfirmingPayment: true);
        payState = readyPay.copyWith(isConfirmingPayment: true);
        sellStates.add(sellState);
        payStates.add(payState);
        await tester.pump();
        expect(find.byType(BullButton), findsNothing);
        expect(find.byType(BullAsyncStatus), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(BullFadingLinearProgress), findsOneWidget);
        expect(find.byType(BullShimmerLine), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
