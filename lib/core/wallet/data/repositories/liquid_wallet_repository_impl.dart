import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/impl/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';

class LiquidWalletRepositoryImpl implements LiquidWalletRepository {
  // TODO: move db to datasource of the required data here and inject the
  //  respective datasource here instead of db
  final SqliteDatabase _sqlite;
  final SeedDatasource _seed;
  final LwkWalletDatasource _lwkWallet;

  LiquidWalletRepositoryImpl({
    required SqliteDatabase sqliteDatasource,
    required SeedDatasource seedDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
  }) : _sqlite = sqliteDatasource,
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
    final metadata =
        await _sqlite.managers.walletMetadatas
            .filter((e) => e.id(walletId))
            .getSingleOrNull();

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

  @override
  Future<(int, int)> getPsetAmountAndFees({
    required String walletId,
    required String pset,
  }) async {
    final metadata =
        await _sqlite.managers.walletMetadatas
            .filter((e) => e.id(walletId))
            .getSingleOrNull();

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
    final (amount, fees) = await _lwkWallet.decodePsbtAmounts(
      wallet: wallet,
      pset: pset,
    );
    return (amount, fees);
  }

  @override
  Future<String> signPset({
    required String pset,
    required String walletId,
  }) async {
    final metadata =
        await _sqlite.managers.walletMetadatas
            .filter((e) => e.id(walletId))
            .getSingleOrNull();

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
