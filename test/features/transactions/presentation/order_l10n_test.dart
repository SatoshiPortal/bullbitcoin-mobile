import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/transactions/presentation/order_l10n.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<String> _typeLabelInFrench(WidgetTester tester, Order order) async {
  late String label;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          label = order.typeLabel(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return label;
}

Order _genericOrder(OrderType type, String name) => Order.generic(
  orderId: 'order-1',
  orderType: type,
  orderTypeName: name,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 1,
  payinCurrency: 'USDT',
  payoutAmount: 1,
  payoutCurrency: 'CAD',
  payinMethod: OrderPaymentMethod.eTransfer,
  payoutMethod: OrderPaymentMethod.eTransfer,
  orderStatus: OrderStatus.completed,
  payinStatus: OrderPayinStatus.completed,
  payoutStatus: OrderPayoutStatus.completed,
  createdAt: DateTime(2026),
  isTestnet: false,
);

void main() {
  testWidgets('translates an order type this build knows', (tester) async {
    expect(
      await _typeLabelInFrench(
        tester,
        _genericOrder(OrderType.sellUsdt, 'Sell USDT'),
      ),
      'Vendre des USDT',
    );
  });

  testWidgets('shows the server name of an order type added later', (
    tester,
  ) async {
    expect(
      await _typeLabelInFrench(
        tester,
        _genericOrder(OrderType.unknown, 'Buy Gold Bars'),
      ),
      'Buy Gold Bars',
    );
  });
}
