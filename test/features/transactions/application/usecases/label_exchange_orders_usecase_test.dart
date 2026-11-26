import 'package:primitives/primitives.dart';

import 'dart:typed_data';

import 'package:exchange/exchange.dart';
import 'package:transactions/testing.dart';
import 'package:labels/labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabels extends Mock implements Labels {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

void main() {
  late _MockLabels labelsFacade;
  late _MockWalletTransactionRepository walletTransactionRepository;
  late LabelExchangeOrdersUsecase usecase;

  setUpAll(() {
    registerFallbackValue(
      NewLabel.tx(transactionId: 'fallback', label: 'fallback'),
    );
  });

  setUp(() {
    labelsFacade = _MockLabels();
    walletTransactionRepository = _MockWalletTransactionRepository();
    usecase = LabelExchangeOrdersUsecase(
      labelsFacade: labelsFacade,
      walletTransactionRepository: walletTransactionRepository,
    );

    // The wallet really did receive this payout: labels are only written on
    // references it owns.
    when(
      () => walletTransactionRepository.getWalletTransactions(
        txId: any(named: 'txId'),
        walletId: any(named: 'walletId'),
        toAddress: any(named: 'toAddress'),
        environment: any(named: 'environment'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer(
      (_) async => Ok([
        WalletTransaction(
          walletId: 'wallet-1',
          network: BitcoinNetwork.mainnet,
          direction: WalletTransactionDirection.incoming,
          status: WalletTransactionStatus.confirmed,
          txId: 'buy-txid',
          amountSat: 100000,
          feeSat: 0,
          vsize: 141,
          inputs: const [],
          outputs: [
            TransactionOutput.bitcoin(
              txId: 'buy-txid',
              vout: 0,
              isOwn: true,
              scriptPubkey: Uint8List(0),
              address: 'bc1qbuy',
            ),
          ],
          isRbf: false,
        ),
      ]),
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
      when(() => labelsFacade.fetch()).thenAnswer(
        (_) async => Ok([
          Label.tx(
            id: 1,
            transactionId: 'sell-txid',
            label: LabelSystem.exchangeSell.label,
          ),
        ]),
      );
      when(() => labelsFacade.store(any())).thenAnswer(storeLabel);

      await usecase.execute(orders: [buyOrder()], explicitCompletion: true);

      final stored = verify(() => labelsFacade.store(captureAny())).captured
          .cast<NewLabel>();
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
    },
  );

  test('does not store an exchange label that already exists', () async {
    when(() => labelsFacade.fetch()).thenAnswer(
      (_) async => Ok([
        Label.addr(
          id: 1,
          address: 'bc1qbuy',
          label: LabelSystem.exchangeBuy.label,
        ),
      ]),
    );
    when(() => labelsFacade.store(any())).thenAnswer(storeLabel);

    await usecase.execute(orders: [buyOrder()], explicitCompletion: true);

    final stored = verify(() => labelsFacade.store(captureAny())).captured
        .cast<NewLabel>();
    expect(stored, hasLength(1));
    expect(stored.single.type, LabelType.transaction);
    expect(stored.single.reference, 'buy-txid');
  });
}
