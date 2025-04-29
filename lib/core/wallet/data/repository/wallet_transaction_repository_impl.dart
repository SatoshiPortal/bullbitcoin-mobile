import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

class WalletTransactionRepositoryImpl implements WalletTransactionRepository {
  final SqliteDatasource _sqlite;
  final WalletDatasource _bdkWalletTransactionDatasource;
  final WalletDatasource _lwkWalletTransactionDatasource;
  final ElectrumServerStorageDatasource _electrumServerStorage;

  WalletTransactionRepositoryImpl({
    required SqliteDatasource sqliteDatasource,
    required WalletDatasource bdkWalletTransactionDatasource,
    required WalletDatasource lwkWalletTransactionDatasource,
    required ElectrumServerStorageDatasource electrumServerStorage,
  })  : _sqlite = sqliteDatasource,
        _bdkWalletTransactionDatasource = bdkWalletTransactionDatasource,
        _lwkWalletTransactionDatasource = lwkWalletTransactionDatasource,
        _electrumServerStorage = electrumServerStorage;

  /*@override
  // TODO: implement walletTransactions
  Stream<List<WalletTransaction>> get walletTransactions =>
      throw UnimplementedError();*/

  @override
  Future<List<WalletTransaction>> getWalletTransactions({
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  }) async {
    final List<WalletTransaction> transactions = [];

    final walletModels = await _getPublicWalletModels(
      walletId: walletId,
      environment: environment,
      sync: sync,
    );
    for (final walletModel in walletModels) {
      final walletTransactionDatasource = walletModel is PublicBdkWalletModel
          ? _bdkWalletTransactionDatasource
          : _lwkWalletTransactionDatasource;

      final transactionModels =
          await walletTransactionDatasource.getTransactions(
        wallet: walletModel,
        toAddress: toAddress,
      );

      for (final transactionModel in transactionModels) {
        transactions.add(transactionModel.toEntity(walletId: walletModel.id));
      }
    }

    return transactions;
  }

  @override
  Future<WalletTransaction> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  }) async {
    final transactions = await getWalletTransactions(
      walletId: walletId,
      sync: sync,
    );

    final transaction = transactions.firstWhere(
      (transaction) => transaction.txId == txId,
      orElse: () => throw Exception('Transaction not found'),
    );

    return transaction;
  }

  Future<List<WalletModel>> _getPublicWalletModels({
    String? walletId,
    Environment? environment,
    bool sync = false,
  }) async {
    List<WalletMetadataModel> walletsMetadata;
    if (walletId == null) {
      walletsMetadata = await _sqlite.managers.walletMetadatas.get();
    } else {
      final metadata = await _sqlite.managers.walletMetadatas
          .filter((e) => e.id(walletId))
          .getSingleOrNull();

      if (metadata == null) {
        throw Exception('Wallet metadata not found');
      }

      walletsMetadata = [metadata];
    }

    final filteredWalletsMetadata = walletsMetadata.where(
      (metadata) =>
          environment == null || environment.isTestnet == metadata.isTestnet,
    );
    final walletModels = filteredWalletsMetadata
        .map(
          (metadata) => metadata.isBitcoin
              ? WalletModel.publicBdk(
                  externalDescriptor: metadata.externalPublicDescriptor,
                  internalDescriptor: metadata.internalPublicDescriptor,
                  isTestnet: metadata.isTestnet,
                  id: metadata.id,
                )
              : WalletModel.publicLwk(
                  combinedCtDescriptor: metadata.externalPublicDescriptor,
                  isTestnet: metadata.isTestnet,
                  id: metadata.id,
                ),
        )
        .toList();

    if (sync) {
      await Future.wait(
        walletModels.map((walletModel) async {
          final isLiquid = walletModel is PublicLwkWalletModel;

          final electrumServer =
              await _electrumServerStorage.getDefaultServerByProvider(
                    DefaultElectrumServerProvider.blockstream,
                    network: Network.fromEnvironment(
                      isTestnet: walletModel.isTestnet,
                      isLiquid: isLiquid,
                    ),
                  ) ??
                  ElectrumServerModel.blockstream(
                    isTestnet: walletModel.isTestnet,
                    isLiquid: isLiquid,
                  );

          final walletTransactionDatasource = isLiquid
              ? _lwkWalletTransactionDatasource
              : _bdkWalletTransactionDatasource;

          return walletTransactionDatasource.sync(
            wallet: walletModel,
            electrumServer: electrumServer,
          );
        }),
      );
    }

    return walletModels;
  }
}
