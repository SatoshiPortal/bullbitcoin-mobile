import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';

class BitcoinWalletRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SeedDatasource _seed;
  final BdkWalletDatasource _bdkWallet;

  BitcoinWalletRepository({
    required WalletMetadataDatasource walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
  }) : _walletMetadataDatasource = walletMetadataDatasource,
       _seed = seedDatasource,
       _bdkWallet = bdkWalletDatasource;

  Future<String> buildPsbt({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxo>? selected,
    bool? replaceByFee,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }

    final wallet =
        WalletModel.publicBdk(
              externalDescriptor: metadata.externalPublicDescriptor,
              internalDescriptor: metadata.internalPublicDescriptor,
              isTestnet: metadata.isTestnet,
              id: metadata.id,
            )
            as PublicBdkWalletModel;
    final psbt = await _bdkWallet.buildPsbt(
      wallet: wallet,
      address: address,
      amountSat: amountSat,
      networkFee: networkFee,
      drain: drain,
      unspendable: unspendable,
      selected:
          selected?.map((utxo) => WalletUtxoMapper.fromEntity(utxo)).toList(),
      replaceByFee: replaceByFee ?? false,
    );

    return psbt;
  }

  Future<String> signPsbt(String psbt, {required String walletId}) async {
    final wallet = await getPrivateWallet(walletId: walletId);
    final signedPsbt = await _bdkWallet.signPsbt(wallet: wallet, psbt);
    return signedPsbt;
  }

  Future<bool> isScriptOfWallet({
    required String walletId,
    required Uint8List script,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }

    final wallet =
        WalletModel.publicBdk(
              externalDescriptor: metadata.externalPublicDescriptor,
              internalDescriptor: metadata.internalPublicDescriptor,
              isTestnet: metadata.isTestnet,
              id: metadata.id,
            )
            as PublicBdkWalletModel;

    final isFromWallet = await _bdkWallet.isMine(script, wallet: wallet);

    return isFromWallet;
  }

  Future<int> getTxSize({required String psbt}) async {
    final txSize = await _bdkWallet.decodeTxSize(psbt);
    return txSize;
  }

  Future<int> getTxFeeAmount({required String psbt}) async {
    final feeAbsolute = await _bdkWallet.getFeeAmount(psbt);
    return feeAbsolute;
  }

  Future<int> getAmountSentToAddress({
    required String psbt,
    required String address,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }
    return await _bdkWallet.getAmountSentToAddress(
      psbt,
      address,
      isTestnet: metadata.isTestnet,
    );
  }

  Future<PrivateBdkWalletModel> getPrivateWallet({
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }

    final seed =
        await _seed.get(metadata.masterFingerprint) as MnemonicSeedModel;
    final mnemonic = seed.mnemonicWords.join(' ');

    final wallet =
        WalletModel.privateBdk(
              id: metadata.id,
              mnemonic: mnemonic,
              passphrase: seed.passphrase,
              scriptType: metadata.scriptType,
              isTestnet: metadata.isTestnet,
            )
            as PrivateBdkWalletModel;
    return wallet;
  }

  Future<String> bumpFee({
    required String walletId,
    required String txid,
    required double newFeeRate,
  }) async {
    final wallet = await getPrivateWallet(walletId: walletId);
    final psbt = await _bdkWallet.createUnsignedReplaceByFeePsbt(
      wallet: wallet,
      txid: txid,
      feeRate: newFeeRate,
    );
    final signedPsbt = await signPsbt(psbt, walletId: walletId);
    return signedPsbt;
  }
}
