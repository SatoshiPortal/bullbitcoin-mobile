import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/label_exchange_orders_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockListAllOrdersUsecase extends Mock implements ListAllOrdersUsecase {}

void main() {
  late _MockLabelsFacade labelsFacade;
  late _MockListAllOrdersUsecase listAllOrdersUsecase;
  late LabelExchangeOrdersUsecase usecase;

  setUpAll(() {
    registerFallbackValue(
      NewLabel.tx(transactionId: 'fallback', label: 'fallback'),
    );
  });

  setUp(() {
    labelsFacade = _MockLabelsFacade();
    listAllOrdersUsecase = _MockListAllOrdersUsecase();
    usecase = LabelExchangeOrdersUsecase(
      labelsFacade: labelsFacade,
      listAllOrdersUsecase: listAllOrdersUsecase,
    );
  });

  Order buyOrder() => Order.buy(
    orderId: 'buy-order',
    orderType: OrderType.buy,
    message: OrderMessage(code: '', message: ''),
    orderNumber: 1,
    payinAmount: 100,
    payinCurrency: 'CAD',
    payoutAmount: 0.001,
    payoutCurrency: 'BTC',
    payinMethod: OrderPaymentMethod.cadBalance,
    payoutMethod: OrderPaymentMethod.bitcoin,
    orderStatus: OrderStatus.completed,
    payinStatus: OrderPayinStatus.completed,
    payoutStatus: OrderPayoutStatus.completed,
    confirmationDeadline: DateTime.utc(2026, 7, 29, 12, 5),
    createdAt: DateTime.utc(2026, 7, 29, 12),
    bitcoinAddress: 'bc1qbuy',
    bitcoinTransactionId: 'buy-txid',
    isTestnet: false,
  );

  Future<Result<Label, LabelFailure>> storeLabel(Invocation invocation) async {
    final label = invocation.positionalArguments.single as NewLabel;
    return Ok(
      Label(
        id: 2,
        type: label.type,
        label: label.label,
        reference: label.reference,
        origin: label.origin,
      ),
    );
  }

  test(
    'existing sell label does not prevent buy labels from being stored',
    () async {
      when(() => labelsFacade.fetchAll()).thenAnswer(
        (_) async => [
          Label.tx(
            id: 1,
            transactionId: 'sell-txid',
            label: LabelSystem.exchangeSell.label,
          ),
        ],
      );
      when(() => labelsFacade.store(any())).thenAnswer(storeLabel);

      await usecase.execute(orders: [buyOrder()]);

      final stored = verify(
        () => labelsFacade.store(captureAny()),
      ).captured.cast<NewLabel>();
      expect(stored, hasLength(2));
      expect(
        stored,
        contains(
          isA<NewLabel>()
              .having((label) => label.type, 'type', LabelType.address)
              .having((label) => label.label, 'label', 'exchange_buy')
              .having((label) => label.reference, 'reference', 'bc1qbuy'),
        ),
      );
      expect(
        stored,
        contains(
          isA<NewLabel>()
              .having((label) => label.type, 'type', LabelType.transaction)
              .having((label) => label.label, 'label', 'exchange_buy')
              .having((label) => label.reference, 'reference', 'buy-txid'),
        ),
      );
      verifyNever(() => listAllOrdersUsecase.execute());
    },
  );

  test('does not store an exchange label that already exists', () async {
    when(() => labelsFacade.fetchAll()).thenAnswer(
      (_) async => [
        Label.addr(
          id: 1,
          address: 'bc1qbuy',
          label: LabelSystem.exchangeBuy.label,
        ),
      ],
    );
    when(() => labelsFacade.store(any())).thenAnswer(storeLabel);

    await usecase.execute(orders: [buyOrder()]);

    final stored = verify(
      () => labelsFacade.store(captureAny()),
    ).captured.cast<NewLabel>();
    expect(stored, hasLength(1));
    expect(stored.single.type, LabelType.transaction);
    expect(stored.single.reference, 'buy-txid');
  });
}
