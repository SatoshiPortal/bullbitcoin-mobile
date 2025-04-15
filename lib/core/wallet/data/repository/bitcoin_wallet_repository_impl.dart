import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/utxo/data/models/utxo_model.dart';
import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/private_wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';

class BitcoinWalletRepositoryImpl implements BitcoinWalletRepository {
  final WalletMetadataDatasource _walletMetadata;
  final SeedDatasource _seed;
  final BdkWalletDatasource _bdkWallet;

  BitcoinWalletRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
  })  : _walletMetadata = walletMetadataDatasource,
        _seed = seedDatasource,
        _bdkWallet = bdkWalletDatasource;

  @override
  Future<String> buildPsbt({
    required String origin,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<Utxo>? unspendable,
    List<Utxo>? selected,
    bool? replaceByFee,
  }) async {
    final metadata = await _walletMetadata.get(origin);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for origin: $origin');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $origin is not a Bitcoin wallet');
    }

    final wallet = PublicBdkWalletModel(
      externalDescriptor: metadata.externalPublicDescriptor,
      internalDescriptor: metadata.internalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.origin,
    );
    final psbt = await _bdkWallet.buildPsbt(
      wallet: wallet,
      address: address,
      amountSat: amountSat,
      networkFee: networkFee,
      drain: drain,
      unspendable:
          unspendable?.map((utxo) => UtxoModel.fromEntity(utxo)).toList(),
      selected: selected?.map((utxo) => UtxoModel.fromEntity(utxo)).toList(),
      replaceByFee: replaceByFee ?? false,
    );

    return psbt;
  }

  @override
  Future<String> signPsbt(
    String psbt, {
    required String origin,
  }) async {
    final metadata = await _walletMetadata.get(origin);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for origin: $origin');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $origin is not a Bitcoin wallet');
    }

    final seed =
        await _seed.get(metadata.masterFingerprint) as MnemonicSeedModel;
    final mnemonic = seed.mnemonicWords.join(' ');

    final wallet = PrivateBdkWalletModel(
      mnemonic: mnemonic,
      passphrase: seed.passphrase,
      scriptType: ScriptType.fromName(metadata.scriptType),
      isTestnet: metadata.isTestnet,
      dbName: metadata.origin,
    );

    final signedPsbt = await _bdkWallet.signPsbt(
      wallet: wallet,
      psbt,
    );

    return signedPsbt;
  }

  @override
  Future<bool> isScriptOfWallet({
    required String origin,
    required Uint8List script,
  }) async {
    final metadata = await _walletMetadata.get(origin);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for origin: $origin');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $origin is not a Bitcoin wallet');
    }

    final wallet = PublicBdkWalletModel(
      externalDescriptor: metadata.externalPublicDescriptor,
      internalDescriptor: metadata.internalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.origin,
    );

    final isFromWallet = await _bdkWallet.isMine(script, wallet: wallet);

    return isFromWallet;
  }
}
