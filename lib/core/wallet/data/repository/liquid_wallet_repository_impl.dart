import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/private_wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';

class LiquidWalletRepositoryImpl implements LiquidWalletRepository {
  final WalletMetadataDatasource _walletMetadata;
  final SeedDatasource _seed;
  final LwkWalletDatasource _lwkWallet;

  LiquidWalletRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
  })  : _walletMetadata = walletMetadataDatasource,
        _seed = seedDatasource,
        _lwkWallet = lwkWalletDatasource;

  @override
  Future<String> buildPset({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
  }) async {
    final metadata = await _walletMetadata.get(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }

    final wallet = PublicLwkWalletModel(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      dbName: metadata.id,
    );
    final pset = await _lwkWallet.buildPset(
      wallet: wallet,
      address: address,
      amountSat: amountSat,
      networkFee: networkFee,
      drain: drain ?? false,
    );

    return pset;
  }

  @override
  Future<Uint8List> signPset(
    String pset, {
    required String walletId,
  }) async {
    final metadata = await _walletMetadata.get(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }

    final seed =
        await _seed.get(metadata.masterFingerprint) as MnemonicSeedModel;
    final mnemonic = seed.mnemonicWords.join(' ');

    final wallet = PrivateLwkWalletModel(
      mnemonic: mnemonic,
      isTestnet: metadata.isTestnet,
      dbName: metadata.id,
    );
    final signedPsbt = await _lwkWallet.signPset(
      wallet: wallet,
      pset,
    );

    return signedPsbt;
  }
}
