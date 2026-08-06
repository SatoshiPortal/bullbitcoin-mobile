import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockGetTransactionsByTxIdUsecase extends Mock
    implements GetTransactionsByTxIdUsecase {}

class _MockGetWalletTransactionUsecase extends Mock
    implements GetWalletTransactionUsecase {}

class _MockGetTransactionOrderSwapUsecase extends Mock
    implements GetTransactionOrderSwapUsecase {}

class _MockWatchWalletTransactionByTxIdUsecase extends Mock
    implements WatchWalletTransactionByTxIdUsecase {}

class _MockGetSwapUsecase extends Mock implements GetSwapUsecase {}

class _MockGetPayjoinByIdUsecase extends Mock
    implements GetPayjoinByIdUsecase {}

class _MockGetOrderUsecase extends Mock implements GetOrderUsecase {}

class _MockWatchSwapUsecase extends Mock implements WatchSwapUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockWatchTransactionOrderSwapUsecase extends Mock
    implements WatchTransactionOrderSwapUsecase {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockBroadcastOriginalTransactionUsecase extends Mock
    implements BroadcastOriginalTransactionUsecase {}

void main() {
  test(
    'loads and watches transaction details by order swap local id',
    () async {
      final getWallet = _MockGetWalletUsecase();
      final getTransactions = _MockGetTransactionsByTxIdUsecase();
      final getOrderSwap = _MockGetTransactionOrderSwapUsecase();
      final watchOrderSwap = _MockWatchTransactionOrderSwapUsecase();
      final record = _record();
      when(
        () => getOrderSwap.execute('local-1'),
      ).thenAnswer((_) async => record);
      when(
        () => watchOrderSwap.execute('local-1'),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => getWallet.execute('wallet-1'),
      ).thenAnswer((_) async => _wallet('wallet-1', Network.liquidTestnet));
      when(
        () => getWallet.execute('wallet-2'),
      ).thenAnswer((_) async => _wallet('wallet-2', Network.bitcoinTestnet));
      when(
        () => getTransactions.execute('payin-tx'),
      ).thenAnswer((_) async => [Transaction(orderSwap: record)]);
      final cubit = TransactionDetailsCubit(
        getWalletUsecase: getWallet,
        getTransactionsByTxIdUsecase: getTransactions,
        getWalletTransactionUsecase: _MockGetWalletTransactionUsecase(),
        getTransactionOrderSwapUsecase: getOrderSwap,
        watchWalletTransactionByTxIdUsecase:
            _MockWatchWalletTransactionByTxIdUsecase(),
        getSwapUsecase: _MockGetSwapUsecase(),
        getPayjoinByIdUsecase: _MockGetPayjoinByIdUsecase(),
        getOrderUsecase: _MockGetOrderUsecase(),
        watchSwapUsecase: _MockWatchSwapUsecase(),
        watchPayjoinUsecase: _MockWatchPayjoinUsecase(),
        watchTransactionOrderSwapUsecase: watchOrderSwap,
        labelsFacade: _MockLabelsFacade(),
        broadcastOriginalTransactionUsecase:
            _MockBroadcastOriginalTransactionUsecase(),
      );
      addTearDown(cubit.close);

      await cubit.initByOrderSwapLocalId('local-1');

      expect(cubit.state.transaction?.orderSwap?.localId, 'local-1');
      expect(cubit.state.wallet?.id, 'wallet-1');
      expect(cubit.state.counterpartWallet?.id, 'wallet-2');
    },
  );
}

Wallet _wallet(String id, Network network) => Wallet(
  origin: id,
  network: network,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

OrderSwapRecord _record() => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.transfer,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.bitcoin,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(103000),
  sourceWalletId: 'wallet-1',
  destinationWalletId: 'wallet-2',
  destination: 'tb1destination',
  fallback: 'tlq1fallback',
  order: OrderSwap(
    orderId: 'order-1',
    orderNumber: 1,
    inNetwork: OrderSwapNetwork.liquid,
    outNetwork: OrderSwapNetwork.bitcoin,
    payinAmountSat: BigInt.from(104030),
    payoutAmountSat: BigInt.from(103000),
    payinCurrency: 'LBTC',
    payoutCurrency: 'BTC',
    payinMethod: 'Liquid',
    payoutMethod: 'Bitcoin',
    orderType: 'Swap',
    orderStatus: 'In progress',
    payinStatus: 'Completed',
    payoutStatus: 'In progress',
    messageCode: 'PAYOUT_IN_PROGRESS',
    bitcoinTransactionId: null,
    liquidTransactionId: 'payin-tx',
    createdAt: DateTime.utc(2026),
    confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
  ),
  localPayinTransactionId: 'payin-tx',
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.payoutInProgress,
);
