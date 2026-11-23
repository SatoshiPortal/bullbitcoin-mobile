import 'package:primitives/primitives.dart';
import 'package:exchange/testing.dart';

// Behavioral proof for two audit findings on GetTransactionsUsecase
// (issues #2663 and #2664 fixes).
//
// `fix(transactions)` added an address/direction check for orders and a
// wallet-id/amount-ceiling check for swaps, but both still accept whatever the
// server reports: the order amount is never compared with the on-chain amount,
// and a swap is bound without checking that the transaction actually pays the
// swap's lockup address.
import 'dart:typed_data';

import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:swaps/swaps.dart' as swaps show Environment;
import 'package:transactions/testing.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' as bb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The use case returns a `Result`; these tests are about what it binds, so a
/// failure is a test failure rather than a case to assert on.
List<Transaction> _transactionsOf(
  bb.Result<List<Transaction>, TransactionFailure> result,
) => switch (result) {
  bb.Ok(:final value) => value,
  bb.Err(:final failure) => fail('expected transactions, got $failure'),
};

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockSwapStore extends Mock implements SwapStore {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockExchangeOrders extends Mock implements ExchangeOrders {}

class _MockLabelExchangeOrdersUsecase extends Mock
    implements LabelExchangeOrdersUsecase {}

class _MockGetTransactionOrderSwapsUsecase extends Mock
    implements GetTransactionOrderSwapsUsecase {}

WalletTransaction _walletTransaction({
  required String txId,
  required WalletTransactionDirection direction,
  required int amountSat,
  required String address,
  String walletId = 'wallet-1',
}) => WalletTransaction(
  walletId: walletId,
  network: BitcoinNetwork.mainnet,
  direction: direction,
  status: WalletTransactionStatus.confirmed,
  txId: txId,
  amountSat: amountSat,
  feeSat: 250,
  vsize: 141,
  inputs: const [],
  outputs: [
    TransactionOutput.bitcoin(
      txId: txId,
      vout: 0,
      isOwn: direction == WalletTransactionDirection.incoming,
      scriptPubkey: Uint8List(0),
      address: address,
    ),
  ],
  isRbf: false,
);

void main() {
  late _MockSettingsRepository settingsRepository;
  late _MockWalletTransactionRepository walletTransactionRepository;
  late _MockSwapStore swapStore;
  late _MockPayjoinSessions payjoinSessions;
  late _MockExchangeOrders orderRepository;
  late _MockLabelExchangeOrdersUsecase labelExchangeOrdersUsecase;
  late _MockGetTransactionOrderSwapsUsecase getTransactionOrderSwapsUsecase;
  late GetTransactionsUsecase usecase;

  setUpAll(() {
    registerFallbackValue(PayjoinSessionFilter());
  });

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    walletTransactionRepository = _MockWalletTransactionRepository();
    swapStore = _MockSwapStore();
    payjoinSessions = _MockPayjoinSessions();
    orderRepository = _MockExchangeOrders();
    labelExchangeOrdersUsecase = _MockLabelExchangeOrdersUsecase();
    getTransactionOrderSwapsUsecase = _MockGetTransactionOrderSwapsUsecase();

    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    when(() => payjoinSessions.list(any()))
        .thenAnswer((_) async => const Ok([]));
    when(() => swapStore.all(walletId: any(named: 'walletId')))
        .thenAnswer((_) async => const Ok(<Swap>[]));
    when(() => orderRepository.getOrders())
        .thenAnswer((_) async => const Ok(<Order>[]));
    when(() => labelExchangeOrdersUsecase.execute(orders: any(named: 'orders')))
        .thenAnswer((_) async {});
    when(
      () => getTransactionOrderSwapsUsecase.execute(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => const Ok([]));

    usecase = GetTransactionsUsecase(
      settingsRepository: settingsRepository,
      walletTransactionRepository: walletTransactionRepository,
      swapStore: swapStore,
      payjoinSessions: payjoinSessions,
      exchange: exchangeForTesting(
        orders: (environment) => environment == ExchangeEnvironment.testnet
            ? _MockExchangeOrders()
            : orderRepository,
      ),
      labelExchangeOrdersUsecase: labelExchangeOrdersUsecase,
      getTransactionOrderSwapsUsecase: getTransactionOrderSwapsUsecase,
    );
  });

  test(
    'an order whose amount contradicts the on-chain amount is not bound',
    () async {
      final tx = _walletTransaction(
        txId: 'shared-txid',
        direction: WalletTransactionDirection.incoming,
        amountSat: 100000, // 0.001 BTC actually received
        address: 'bc1qmywallet',
      );
      when(
        () => walletTransactionRepository.getWalletTransactions(
          walletId: any(named: 'walletId'),
          sync: any(named: 'sync'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => Ok([tx]));
      when(() => orderRepository.getOrders()).thenAnswer(
        (_) async => Ok([
          Order.buy(
            orderId: 'order-1',
            orderType: OrderType.buy,
            message: OrderMessage(code: '', message: ''),
            orderNumber: 1,
            payinAmount: 500000,
            payinCurrency: 'CAD',
            // The server claims 5 BTC for a transaction that moved 0.001 BTC.
            payoutAmount: 5,
            payoutCurrency: 'BTC',
            payinMethod: OrderPaymentMethod.cadBalance,
            payoutMethod: OrderPaymentMethod.bitcoin,
            orderStatus: OrderStatus.completed,
            payinStatus: OrderPayinStatus.completed,
            payoutStatus: OrderPayoutStatus.completed,
            confirmationDeadline: DateTime.utc(2026, 7, 29, 12, 5),
            createdAt: DateTime.utc(2026, 7, 29, 12),
            bitcoinAddress: 'bc1qmywallet',
            bitcoinTransactionId: 'shared-txid',
            isTestnet: false,
          ),
        ]),
      );

      final transactions = _transactionsOf(await usecase.execute());

      final walletRow = transactions.firstWhere(
        (t) => t.walletTransaction?.txId == 'shared-txid',
      );
      expect(
        walletRow.order,
        isNull,
        reason: 'the reported order amount must be checked against the chain',
      );
    },
  );

  test(
    'a swap is not bound to a transaction that never paid its lockup address',
    () async {
      final tx = _walletTransaction(
        txId: 'wallet-txid',
        direction: WalletTransactionDirection.outgoing,
        amountSat: 50000,
        address: 'bc1qsomewhere-else',
      );
      when(
        () => walletTransactionRepository.getWalletTransactions(
          walletId: any(named: 'walletId'),
          sync: any(named: 'sync'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => Ok([tx]));
      when(() => swapStore.all(walletId: any(named: 'walletId'))).thenAnswer(
        (_) async => Ok([
          Swap.lnSend(
            id: 'swap-1',
            keyIndex: 0,
            type: SwapType.bitcoinToLightning,
            status: SwapStatus.pending,
            environment: swaps.Environment.mainnet,
            creationTime: DateTime.utc(2026, 7, 29, 12),
            sendWalletId: 'wallet-1',
            invoice: 'lnbc1',
            // Server-reported lockup details that the transaction contradicts.
            paymentAddress: 'bc1qswap-lockup-address',
            paymentAmount: 900000,
            sendTxid: 'wallet-txid',
          ),
        ]),
      );

      final transactions = _transactionsOf(await usecase.execute());

      expect(transactions, isNotEmpty);
      final walletRow = transactions.firstWhere(
        (t) => t.walletTransaction?.txId == 'wallet-txid',
      );
      expect(
        walletRow.swap,
        isNull,
        reason: 'a swap claim must be verified against the on-chain outputs',
      );
    },
  );
}
