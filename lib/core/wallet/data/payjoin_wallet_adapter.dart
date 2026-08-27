import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

final class PayjoinWalletAdapter implements PayjoinWalletPort {
  final SeedDatasource _seed;
  final BdkWalletDatasource _wallet;
  final WalletMetadataDatasource _metadata;

  const PayjoinWalletAdapter(this._seed, this._wallet, this._metadata);

  @override
  Future<String> signPsbt({
    required String walletId,
    required BitcoinNetwork network,
    required String psbt,
  }) async {
    final wallet = await _loadPrivateWallet(walletId, network);
    return _wallet.signPsbt(psbt, wallet: wallet);
  }

  @override
  Future<bool Function(Uint8List script)> createOwnershipChecker({
    required String walletId,
    required BitcoinNetwork network,
  }) async {
    final wallet = await _loadPrivateWallet(walletId, network);
    return _wallet.createIsMineChecker(wallet: wallet);
  }

  @override
  Future<bool Function(Outpoint outpoint)> createOutpointOwnershipChecker({
    required String walletId,
    required BitcoinNetwork network,
  }) async {
    // A watch-only view is enough: ownership is answered from the local index,
    // no key material involved.
    final metadata = await _loadMetadata(walletId, network);
    final wallet = WalletModel.fromMetadata(metadata);
    return _wallet.createOutpointIsMineChecker(wallet: wallet);
  }

  @override
  Future<String Function(String psbt)> createPsbtProcessor({
    required String walletId,
    required BitcoinNetwork network,
  }) async {
    final wallet = await _loadPrivateWallet(walletId, network);
    return _wallet.createPsbtSigner(wallet: wallet);
  }

  @override
  Future<List<PayjoinUtxo>> spendableUtxos({
    required String walletId,
    required BitcoinNetwork network,
  }) async {
    final metadata = await _loadMetadata(walletId, network);
    final wallet = WalletModel.fromMetadata(metadata);
    final utxos = await _wallet.getUtxos(wallet: wallet);
    return utxos.whereType<BitcoinWalletUtxoModel>().map((utxo) {
      return PayjoinUtxo(
        outpoint: (txId: utxo.txId, vout: utxo.vout),
        value: Sats(utxo.amountSat),
        scriptPubkey: utxo.scriptPubkey,
        confirmed: utxo.confirmations > 0,
      );
    }).toList();
  }

  Future<WalletMetadataModel> _loadMetadata(
    String walletId,
    BitcoinNetwork network,
  ) async {
    final metadata = await _metadata.fetch(walletId);
    if (metadata == null || !metadata.isBitcoin) {
      throw StateError('Bitcoin wallet metadata not found');
    }
    if (metadata.isTestnet == network.isMainnet) {
      throw StateError('Wallet network does not match Payjoin network');
    }
    return metadata;
  }

  Future<PrivateBdkWalletModel> _loadPrivateWallet(
    String walletId,
    BitcoinNetwork network,
  ) async {
    final metadata = await _loadMetadata(walletId, network);
    final seed = await _seed.get(metadata.masterFingerprint);
    if (seed is! MnemonicSeedModel) {
      throw StateError('Payjoin requires a local mnemonic wallet');
    }
    return WalletModel.privateBdk(
          id: walletId,
          scriptType: metadata.scriptType,
          mnemonic: seed.mnemonicWords.join(' '),
          passphrase: seed.passphrase,
          isTestnet: metadata.isTestnet,
        )
        as PrivateBdkWalletModel;
  }
}
