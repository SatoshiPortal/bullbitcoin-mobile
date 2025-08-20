import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/transaction_input_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/transaction_output_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_transaction_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

class WalletTransactionRepositoryImpl implements WalletTransactionRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final LabelDatasource _labelDatasource;
  final BdkWalletDatasource _bdkWalletTransactionDatasource;
  final LwkWalletDatasource _lwkWalletTransactionDatasource;
  final ElectrumServerStorageDatasource _electrumServerStorage;

  WalletTransactionRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required LabelDatasource labelDatasource,
    required BdkWalletDatasource bdkWalletTransactionDatasource,
    required LwkWalletDatasource lwkWalletTransactionDatasource,
    required ElectrumServerStorageDatasource electrumServerStorage,
  }) : _labelDatasource = labelDatasource,
       _walletMetadataDatasource = walletMetadataDatasource,
       _bdkWalletTransactionDatasource = bdkWalletTransactionDatasource,
       _lwkWalletTransactionDatasource = lwkWalletTransactionDatasource,
       _electrumServerStorage = electrumServerStorage;

  @override
  Future<List<WalletTransaction>> getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  }) async {
    final walletModels = await _getPublicWalletModels(
      walletId: walletId,
      environment: environment,
      sync: sync,
    );

    final walletTransactions = await _getWalletTransactions(
      txId: txId,
      walletModels: walletModels,
      toAddress: toAddress,
    );

    return walletTransactions;
  }

  @override
  Future<WalletTransaction?> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  }) async {
    final transactions = await getWalletTransactions(
      txId: txId,
      walletId: walletId,
      sync: sync,
    );

    return transactions.firstOrNull;
  }

  Future<List<WalletTransaction>> _getWalletTransactions({
    required List<WalletModel> walletModels,
    String? txId,
    String? toAddress,
  }) async {
    final walletTransactionLists = await Future.wait(
      walletModels.map((walletModel) async {
        final walletTransactionModels =
            walletModel is PublicBdkWalletModel
                ? await _bdkWalletTransactionDatasource.getTransactions(
                  wallet: walletModel,
                  toAddress: toAddress,
                )
                : await _lwkWalletTransactionDatasource.getTransactions(
                  wallet: walletModel,
                  toAddress: toAddress,
                );

        if (txId != null) {
          walletTransactionModels.retainWhere(
            (transaction) => transaction.txId == txId,
          );
        }

        return await Future.wait(
          walletTransactionModels.map((walletTransactionModel) async {
            final (inputs, outputs, labels) =
                await (
                  Future.wait(
                    walletTransactionModel.inputs.map((inputModel) async {
                      final inputLabels = await _labelDatasource.fetchByRef(
                        inputModel.labelRef,
                      );
                      return TransactionInputMapper.toEntity(
                        inputModel,
                        labels:
                            inputLabels.map((model) => model.label).toList(),
                      );
                    }),
                  ),
                  Future.wait(
                    walletTransactionModel.outputs.map((outputModel) async {
                      final outputLabels = await _labelDatasource.fetchByRef(
                        outputModel.labelRef,
                      );
                      final outputModelAddress = outputModel.address;
                      final addressLabels =
                          outputModelAddress != null
                              ? await _labelDatasource.fetchByRef(
                                outputModelAddress,
                              )
                              : <LabelModel>[];

                      return TransactionOutputMapper.toEntity(
                        outputModel,
                        labels:
                            outputLabels.map((model) => model.label).toList(),
                        addressLabels:
                            addressLabels.map((model) => model.label).toList(),
                        //isFrozen: isFrozen, // Todo: check if frozen
                      );
                    }),
                  ),
                  _labelDatasource.fetchByRef(walletTransactionModel.txId),
                ).wait;

            return WalletTransactionMapper.toEntity(
              walletTransactionModel,
              walletId: walletModel.id,
              inputs: inputs,
              outputs: outputs,
              labels: labels.map((model) => model.label).toList(),
              isRbf: walletTransactionModel.isRbf,
            );
          }).toList(),
        );
      }),
    );

    return walletTransactionLists.expand((tx) => tx).toList();
  }

  Future<List<WalletModel>> _getPublicWalletModels({
    String? walletId,
    Environment? environment,
    bool sync = false,
  }) async {
    List<WalletMetadataModel> walletsMetadata;
    if (walletId == null) {
      walletsMetadata = await _walletMetadataDatasource.fetchAll();
    } else {
      final metadata = await _walletMetadataDatasource.fetch(walletId);
      if (metadata == null) throw Exception('Wallet metadata not found');

      walletsMetadata = [metadata];
    }

    final filteredWalletsMetadata = walletsMetadata.where(
      (metadata) =>
          environment == null || environment.isTestnet == metadata.isTestnet,
    );
    final walletModels =
        filteredWalletsMetadata
            .map(
              (metadata) =>
                  metadata.isBitcoin
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

          final electrumServer = await _electrumServerStorage
              .fetchPrioritizedServer(
                network: Network.fromEnvironment(
                  isTestnet: walletModel.isTestnet,
                  isLiquid: isLiquid,
                ),
              );

          return isLiquid
              ? _lwkWalletTransactionDatasource.sync(
                wallet: walletModel,
                electrumServer: electrumServer,
              )
              : _bdkWalletTransactionDatasource.sync(
                wallet: walletModel,
                electrumServer: electrumServer,
              );
        }),
      );
    }

    return walletModels;
  }
}
