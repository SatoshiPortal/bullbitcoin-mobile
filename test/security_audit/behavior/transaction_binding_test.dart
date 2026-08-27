// Behavioral proof for two audit findings on GetTransactionsUsecase
// (issues #2663 and #2664 fixes).
//
// `fix(transactions)` added an address/direction check for orders and a
// wallet-id/amount-ceiling check for swaps, but both still accept whatever the
// server reports: the order amount is never compared with the on-chain amount,
// and a swap is bound without checking that the transaction actually pays the
// swap's lockup address.
import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swaps_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/label_exchange_orders_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok;

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

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
  network: Network.bitcoinMainnet,
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
  late _MockBoltzSwapRepository boltzSwapRepository;
  late _MockPayjoinSessions payjoinSessions;
  late _MockExchangeOrderRepository orderRepository;
  late _MockLabelExchangeOrdersUsecase labelExchangeOrdersUsecase;
  late _MockGetTransactionOrderSwapsUsecase getTransactionOrderSwapsUsecase;
  late GetTransactionsUsecase usecase;

  setUpAll(() {
    registerFallbackValue(PayjoinSessionFilter());
  });

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    walletTransactionRepository = _MockWalletTransactionRepository();
    boltzSwapRepository = _MockBoltzSwapRepository();
    payjoinSessions = _MockPayjoinSessions();
    orderRepository = _MockExchangeOrderRepository();
    labelExchangeOrdersUsecase = _MockLabelExchangeOrdersUsecase();
    getTransactionOrderSwapsUsecase = _MockGetTransactionOrderSwapsUsecase();

    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => payjoinSessions.list(any()),
    ).thenAnswer((_) async => const Ok([]));
    when(
      () => boltzSwapRepository.getAllSwaps(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => <Swap>[]);
    when(() => orderRepository.getOrders()).thenAnswer((_) async => <Order>[]);
    when(
      () => labelExchangeOrdersUsecase.execute(orders: any(named: 'orders')),
    ).thenAnswer((_) async {});
    when(
      () => getTransactionOrderSwapsUsecase.execute(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => []);

    usecase = GetTransactionsUsecase(
      settingsRepository: settingsRepository,
      walletTransactionRepository: walletTransactionRepository,
      boltzSwapRepository: boltzSwapRepository,
      payjoinSessions: payjoinSessions,
      mainnetExchangeOrderRepository: orderRepository,
      testnetExchangeOrderRepository: _MockExchangeOrderRepository(),
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
      ).thenAnswer((_) async => [tx]);
      when(() => orderRepository.getOrders()).thenAnswer(
        (_) async => [
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
        ],
      );

      final transactions = await usecase.execute();

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
      ).thenAnswer((_) async => [tx]);
      when(
        () => boltzSwapRepository.getAllSwaps(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async => [
          Swap.lnSend(
            id: 'swap-1',
            keyIndex: 0,
            type: SwapType.bitcoinToLightning,
            status: SwapStatus.pending,
            environment: Environment.mainnet,
            creationTime: DateTime.utc(2026, 7, 29, 12),
            sendWalletId: 'wallet-1',
            invoice: 'lnbc1',
            // Server-reported lockup details that the transaction contradicts.
            paymentAddress: 'bc1qswap-lockup-address',
            paymentAmount: 900000,
            sendTxid: 'wallet-txid',
          ),
        ],
      );

      final transactions = await usecase.execute();

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
