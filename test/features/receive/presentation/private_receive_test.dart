import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Wallet _wallet({
  String id = 'public-wallet',
  BitcoinSyncSource source = BitcoinSyncSource.compactBlockFilters,
}) => Wallet(
  origin: id,
  network: Network.bitcoinMainnet,
  bitcoinSyncSource: source,
  xpubFingerprint: 'deadbeef',
  scriptType: ScriptType.bip84,
  xpub: 'public',
  externalPublicDescriptor: 'public/0/*',
  internalPublicDescriptor: 'public/1/*',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);
WalletTransaction _payment({
  WalletTransactionStatus status = WalletTransactionStatus.pending,
  String walletId = 'public-wallet',
}) => WalletTransaction(
  walletId: walletId,
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
  test('private receive waits for confirmation and rejects another wallet', () {
    final state = ReceiveState(
      type: ReceiveType.bitcoin,
      wallet: _wallet(),
      tx: _payment(),
    );
    expect(state.isPaymentReceived, isFalse);
    expect(
      state
          .copyWith(tx: _payment(status: WalletTransactionStatus.confirmed))
          .isPaymentReceived,
      isTrue,
    );
    expect(
      state
          .copyWith(
            wallet: _wallet(id: 'different-wallet'),
            tx: _payment(status: WalletTransactionStatus.confirmed),
          )
          .isPaymentReceived,
      isFalse,
    );
    expect(
      state
          .copyWith(wallet: _wallet(source: BitcoinSyncSource.electrum))
          .isPaymentReceived,
      isTrue,
    );
  });
  test('private receive never waits for a payjoin or first balance', () {
    final state = ReceiveState(
      type: ReceiveType.bitcoin,
      wallet: _wallet(),
      payjoinGloballyEnabled: true,
      payjoinAttemptSettled: false,
    );
    expect(state.isPayjoinLoading, isFalse);
    expect(state.isPayjoinAwaitingFunds, isFalse);
  });
}
