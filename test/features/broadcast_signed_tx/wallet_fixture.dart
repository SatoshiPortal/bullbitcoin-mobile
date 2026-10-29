import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/usecases/load_broadcast_wallets_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Ok, Result;

Wallet publicBroadcastWallet({
  BitcoinSyncSource source = BitcoinSyncSource.electrum,
}) => Wallet(
  origin: source == BitcoinSyncSource.electrum
      ? 'public-wallet'
      : 'private-wallet',
  label: source == BitcoinSyncSource.electrum
      ? 'Public test wallet'
      : 'Private test wallet',
  network: Network.bitcoinMainnet,
  bitcoinSyncSource: source,
  xpubFingerprint: 'deadbeef',
  scriptType: ScriptType.bip84,
  xpub: 'public',
  externalPublicDescriptor: 'public/0/*',
  internalPublicDescriptor: 'public/1/*',
  signer: SignerEntity.none,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

class LoadPublicBroadcastWallets extends Fake
    implements LoadBroadcastWalletsUsecase {
  final List<Wallet> wallets;
  LoadPublicBroadcastWallets([List<Wallet>? wallets])
    : wallets = wallets ?? [publicBroadcastWallet()];
  @override
  Future<Result<List<Wallet>, BroadcastSignedTxFailure>> execute() async =>
      Ok(wallets);
}
