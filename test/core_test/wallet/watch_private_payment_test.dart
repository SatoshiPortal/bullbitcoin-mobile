import 'dart:async';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../features/broadcast_signed_tx/wallet_fixture.dart';

class _Wallets extends Mock implements WalletRepository {}

class _Transactions extends Mock implements WalletTransactionRepository {}

WalletTransaction _tx(WalletTransactionStatus status) => WalletTransaction(
  walletId: 'private-wallet',
  network: Network.bitcoinMainnet,
  direction: WalletTransactionDirection.incoming,
  status: status,
  txId: 'public-tx',
  amountSat: 100,
  feeSat: 0,
  vsize: 100,
  inputs: [],
  outputs: [],
  isRbf: false,
);
void main() {
  test('fresh persisted CBF policy filters a cached pending receive', () async {
    final wallets = _Wallets();
    final transactions = _Transactions();
    final finished = StreamController<Wallet>();
    final events = <WalletTransaction>[];
    when(
      () => wallets.walletSyncFinishedStream,
    ).thenAnswer((_) => finished.stream);
    var tx = _tx(WalletTransactionStatus.pending);
    when(
      () => transactions.getWalletTransactions(
        walletId: 'private-wallet',
        toAddress: 'public-address',
      ),
    ).thenAnswer((_) async => [tx]);
    final subscription =
        WatchWalletTransactionByAddressUsecase(
              walletTransactionRepository: transactions,
              walletRepository: wallets,
            )
            .execute(walletId: 'private-wallet', toAddress: 'public-address')
            .listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(finished.close);
    final wallet = publicBroadcastWallet(
      source: BitcoinSyncSource.compactBlockFilters,
    );
    finished.add(wallet);
    await pumpEventQueue();
    expect(events, isEmpty);
    tx = _tx(WalletTransactionStatus.confirmed);
    finished.add(wallet);
    await pumpEventQueue();
    expect(events.single.isConfirmed, isTrue);
  });
}
