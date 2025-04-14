import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet_transaction/data/datasources/wallet_transaction_datasource.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/repositories/wallet_transaction_repository.dart';

class WalletTransactionRepositoryImpl implements WalletTransactionRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final WalletTransactionDatasource _bdkWalletTransactionDatasource;
  final WalletTransactionDatasource _lwkWalletTransactionDatasource;
  final ElectrumServerStorageDatasource _electrumServerStorage;

  WalletTransactionRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required WalletTransactionDatasource bdkWalletTransactionDatasource,
    required WalletTransactionDatasource lwkWalletTransactionDatasource,
    required ElectrumServerStorageDatasource electrumServerStorage,
  })  : _walletMetadataDatasource = walletMetadataDatasource,
        _bdkWalletTransactionDatasource = bdkWalletTransactionDatasource,
        _lwkWalletTransactionDatasource = lwkWalletTransactionDatasource,
        _electrumServerStorage = electrumServerStorage;

  /*@override
  // TODO: implement walletTransactions
  Stream<List<WalletTransaction>> get walletTransactions =>
      throw UnimplementedError();*/

  @override
  Future<List<WalletTransaction>> getWalletTransactions({
    String? origin,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  }) async {
    final List<WalletTransaction> transactions = [];

    final walletModels = await _getPublicWalletModels(
      origin: origin,
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
        transactions.add(transactionModel.toEntity(origin: walletModel.id));
      }
    }

    return transactions;
  }

  @override
  Future<WalletTransaction> getWalletTransaction(
    String txId, {
    required String origin,
    bool sync = false,
  }) async {
    final transactions = await getWalletTransactions(
      origin: origin,
      sync: sync,
    );

    final transaction = transactions.firstWhere(
      (transaction) => transaction.txId == txId,
      orElse: () => throw Exception('Transaction not found'),
    );

    return transaction;
  }

  Future<List<PublicWalletModel>> _getPublicWalletModels({
    String? origin,
    Environment? environment,
    bool sync = false,
  }) async {
    List<WalletMetadataModel> walletsMetadata;
    if (origin == null) {
      walletsMetadata = await _walletMetadataDatasource.getAll();
    } else {
      final metadata = await _walletMetadataDatasource.get(origin);
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
              ? PublicBdkWalletModel(
                  externalDescriptor: metadata.externalPublicDescriptor,
                  internalDescriptor: metadata.internalPublicDescriptor,
                  isTestnet: metadata.isTestnet,
                  id: metadata.origin,
                )
              : PublicLwkWalletModel(
                  combinedCtDescriptor: metadata.externalPublicDescriptor,
                  isTestnet: metadata.isTestnet,
                  id: metadata.origin,
                ),
        )
        .toList();

    if (sync) {
      await Future.wait(
        walletModels.map((walletModel) async {
          final isLiquid = walletModel is PublicLwkWalletModel;

          final electrumServer = await _electrumServerStorage.getByProvider(
                ElectrumServerProvider.blockstream,
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
