import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

final class PayjoinWalletAdapter implements PayjoinWalletPort {
  final BdkWalletDatasource _wallet;
  final WalletMetadataDatasource _metadata;
  final WalletSigningMaterialResolver _signingMaterial;

  const PayjoinWalletAdapter(
    this._wallet,
    this._metadata,
    this._signingMaterial,
  );

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
    final material = await _signingMaterial.resolve(metadata);
    return WalletModel.privateBdk(
          id: walletId,
          scriptType: metadata.scriptType,
          mnemonic: material.mnemonic,
          passphrase: material.passphrase,
          isTestnet: metadata.isTestnet,
        )
        as PrivateBdkWalletModel;
  }
}
