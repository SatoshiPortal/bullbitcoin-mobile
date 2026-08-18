import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_send_payment_screen.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_send_payment_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _pixel5LogicalSize = Size(392.7272727, 850.9090909);

class _MockPayBloc extends Mock implements PayBloc {}

class _MockSellBloc extends Mock implements SellBloc {}

FiatPaymentOrder _payOrder() => FiatPaymentOrder(
  orderId: 'synthetic-pay',
  orderType: OrderType.fiatPayment,
  message: OrderMessage(code: 'ok', message: 'synthetic'),
  orderNumber: 1,
  payinAmount: 100,
  payinCurrency: 'CAD',
  payoutAmount: 100,
  payoutCurrency: 'CAD',
  payinMethod: OrderPaymentMethod.cadBalance,
  payoutMethod: OrderPaymentMethod.bitcoin,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.awaitingPayment,
  payoutStatus: OrderPayoutStatus.notStarted,
  confirmationDeadline: DateTime(2099),
  createdAt: DateTime(2026),
  isTestnet: true,
);

SellOrder _sellOrder() => SellOrder(
  orderId: 'synthetic-sell',
  orderType: OrderType.sell,
  message: OrderMessage(code: 'ok', message: 'synthetic'),
  orderNumber: 1,
  payinAmount: 0.001,
  payinCurrency: 'BTC',
  payoutAmount: 100,
  payoutCurrency: 'CAD',
  payinMethod: OrderPaymentMethod.bitcoin,
  payoutMethod: OrderPaymentMethod.cadBalance,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.awaitingPayment,
  payoutStatus: OrderPayoutStatus.notStarted,
  confirmationDeadline: DateTime(2099),
  createdAt: DateTime(2026),
  isTestnet: true,
);

Widget _app(Widget child, List<BlocProvider<dynamic>> providers) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) {
    Device.init(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(size: _pixel5LogicalSize),
      child: child!,
    );
  },
  home: MultiBlocProvider(providers: providers, child: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PaySendPaymentScreen fits the Pixel 5 viewport', (tester) async {
    final bloc = _MockPayBloc();
    when(() => bloc.state).thenReturn(
      PayState.payment(
        selectedRecipient: const RecipientViewModel(
          id: 'synthetic-recipient',
          type: RecipientType.interacEmailCad,
          name: 'Synthetic Recipient',
        ),
        userSummary: const UserSummary(
          userNumber: 1,
          groups: ['KYC_IDENTITY_VERIFIED'],
          profile: UserProfile(firstName: 'Synthetic', lastName: 'User'),
          email: 'synthetic@example.invalid',
          balances: [],
          dca: UserDca(isActive: false),
          autoBuy: UserAutoBuy(
            isActive: false,
            addresses: UserAutoBuyAddresses(),
          ),
          currency: 'CAD',
        ),
        amount: const FiatAmount(100),
        payOrder: _payOrder(),
      ),
    );
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    Device.screen = _pixel5LogicalSize;
    await tester.pumpWidget(
      _app(const PaySendPaymentScreen(), [
        BlocProvider<PayBloc>.value(value: bloc),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
  });

  testWidgets('SellSendPaymentScreen fits the Pixel 5 viewport', (
    tester,
  ) async {
    final bloc = _MockSellBloc();
    when(() => bloc.state).thenReturn(
      SellState.payment(
        userSummary: const UserSummary(
          userNumber: 1,
          groups: ['KYC_IDENTITY_VERIFIED'],
          profile: UserProfile(firstName: 'Synthetic', lastName: 'User'),
          email: 'synthetic@example.invalid',
          balances: [],
          dca: UserDca(isActive: false),
          autoBuy: UserAutoBuy(
            isActive: false,
            addresses: UserAutoBuyAddresses(),
          ),
          currency: 'CAD',
        ),
        bitcoinUnit: BitcoinUnit.btc,
        orderAmount: const BitcoinAmount(0.001),
        fiatCurrency: FiatCurrency.cad,
        sellOrder: _sellOrder(),
      ),
    );
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    Device.screen = _pixel5LogicalSize;
    await tester.pumpWidget(
      _app(const SellSendPaymentScreen(), [
        BlocProvider<SellBloc>.value(value: bloc),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
  });
}
