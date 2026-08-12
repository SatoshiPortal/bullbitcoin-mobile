// Behavioral proof for the audit finding on exchange labelling (issue #2624).
//
// `fix(transactions)` gates label writes behind an explicit completion event,
// but the address and transaction id still come straight from the exchange
// response. Nothing checks that the wallet owns them, so a compromised or
// buggy server can still plant privileged, undeletable system labels on
// arbitrary references.
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/label_exchange_orders_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockListAllOrdersUsecase extends Mock implements ListAllOrdersUsecase {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

void main() {
  late _MockLabelsFacade labelsFacade;
  late _MockListAllOrdersUsecase listAllOrdersUsecase;
  late _MockWalletTransactionRepository walletTransactionRepository;
  late LabelExchangeOrdersUsecase usecase;

  setUpAll(() {
    registerFallbackValue(
      NewLabel.tx(transactionId: 'fallback', label: 'fallback'),
    );
  });

  setUp(() {
    labelsFacade = _MockLabelsFacade();
    listAllOrdersUsecase = _MockListAllOrdersUsecase();
    walletTransactionRepository = _MockWalletTransactionRepository();
    usecase = LabelExchangeOrdersUsecase(
      labelsFacade: labelsFacade,
      listAllOrdersUsecase: listAllOrdersUsecase,
      walletTransactionRepository: walletTransactionRepository,
    );

    // The wallet holds no such transaction: the order references are the
    // server's word alone.
    when(
      () => walletTransactionRepository.getWalletTransactions(
        txId: any(named: 'txId'),
        walletId: any(named: 'walletId'),
        toAddress: any(named: 'toAddress'),
        environment: any(named: 'environment'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((_) async => <WalletTransaction>[]);

    when(() => labelsFacade.fetchAll()).thenAnswer((_) async => <Label>[]);
    when(() => labelsFacade.store(any())).thenAnswer((invocation) async {
      final label = invocation.positionalArguments.single as NewLabel;
      return Ok(
        Label(
          id: 1,
          type: label.type,
          label: label.label,
          reference: label.reference,
          origin: label.origin,
        ),
      );
    });
  });

  Order hostileOrder() => Order.buy(
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
    // Neither of these belongs to any wallet held on this device.
    bitcoinAddress: 'bc1qattackercontrolledaddress0000000000000000',
    bitcoinTransactionId:
        '0000000000000000000000000000000000000000000000000000000000000bad',
    isTestnet: false,
  );

  test('does not label references the wallet does not own', () async {
    await usecase.execute(orders: [hostileOrder()], explicitCompletion: true);

    verifyNever(() => labelsFacade.store(any()));
  });
}
