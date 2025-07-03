import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';

class LiquidWalletRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SeedDatasource _seed;
  final LwkWalletDatasource _lwkWallet;

  LiquidWalletRepository({
    required WalletMetadataDatasource walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
  }) : _walletMetadataDatasource = walletMetadataDatasource,
       _seed = seedDatasource,
       _lwkWallet = lwkWalletDatasource;

  Future<String> buildPset({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }

    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
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

  Future<(int, int)> getPsetSizeAndAbsoluteFees({required String pset}) async {
    final (size, fees) = await _lwkWallet.decodeAbsoluteFeesFromPset(pset);
    return (size, fees);
  }

  Future<String> signPset({
    required String pset,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }

    final seed =
        await _seed.get(metadata.masterFingerprint) as MnemonicSeedModel;
    final mnemonic = seed.mnemonicWords.join(' ');

    final wallet =
        WalletModel.privateLwk(
              id: metadata.id,
              mnemonic: mnemonic,
              isTestnet: metadata.isTestnet,
            )
            as PrivateLwkWalletModel;
    final signedPsbt = await _lwkWallet.signPset(wallet: wallet, pset);

    return signedPsbt;
  }
}
