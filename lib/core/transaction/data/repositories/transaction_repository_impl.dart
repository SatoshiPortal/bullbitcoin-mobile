import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/transaction/data/datasources/transaction_datasource.dart';
import 'package:bb_mobile/core/transaction/domain/entities/transaction.dart';
import 'package:bb_mobile/core/transaction/domain/repositories/transaction_repository.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final WalletMetadataDatasource _walletMetadata;
  final TransactionDatasource _bdkWallet;
  final TransactionDatasource _lwkWallet;

  TransactionRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required TransactionDatasource bdkWalletDatasource,
    required TransactionDatasource lwkWalletDatasource,
  })  : _walletMetadata = walletMetadataDatasource,
        _bdkWallet = bdkWalletDatasource,
        _lwkWallet = lwkWalletDatasource;

  @override
  // TODO: implement transactions
  Stream<WalletTransaction> get transactions => throw UnimplementedError();

  @override
  Future<List<WalletTransaction>> getTransactions({
    String? walletId,
    Environment? environment,
  }) async {
    List<WalletMetadataModel> walletsMetadata;
    if (walletId == null) {
      walletsMetadata = await _walletMetadata.getAll();
    } else {
      final metadata = await _walletMetadata.get(walletId);
      if (metadata == null) {
        throw Exception('Wallet metadata not found');
      }
      walletsMetadata = [metadata];
    }

    final filterWalletsMetadata = walletsMetadata.where(
      (metadata) =>
          environment == null || environment.isTestnet == metadata.isTestnet,
    );

    final List<WalletTransaction> transactions = [];

    for (final wallet in filterWalletsMetadata) {
      final walletDatasource = wallet.isBitcoin ? _bdkWallet : _lwkWallet;
      final walletModel = wallet.isBitcoin
          ? PublicBdkWalletModel(
              externalDescriptor: wallet.externalPublicDescriptor,
              internalDescriptor: wallet.internalPublicDescriptor,
              isTestnet: wallet.isTestnet,
              dbName: wallet.id,
            )
          : PublicLwkWalletModel(
              combinedCtDescriptor: wallet.externalPublicDescriptor,
              isTestnet: wallet.isTestnet,
              dbName: wallet.id,
            );

      final transactionModels =
          await walletDatasource.getTransactions(wallet: walletModel);

      for (final transactionModel in transactionModels) {
        transactions.add(transactionModel.toEntity(walletId: wallet.id));
      }
    }

    return transactions;
  }

  @override
  Future<WalletTransaction> getTransaction(
    String txId, {
    required String walletId,
  }) async {
    final transactions = await getTransactions(walletId: walletId);

    final transaction = transactions.firstWhere(
      (transaction) => transaction.txId == txId,
      orElse: () => throw Exception('Transaction not found'),
    );

    return transaction;
  }
}
