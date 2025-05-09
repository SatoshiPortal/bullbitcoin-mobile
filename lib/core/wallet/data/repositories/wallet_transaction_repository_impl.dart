import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/transaction_input_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/transaction_output_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_transaction_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

class WalletTransactionRepositoryImpl implements WalletTransactionRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final LabelDatasource _labelDatasource;
  final WalletDatasource _bdkWalletTransactionDatasource;
  final WalletDatasource _lwkWalletTransactionDatasource;
  final ElectrumServerStorageDatasource _electrumServerStorage;
  final LocalPayjoinDatasource _payjoinDatasource;
  final BoltzStorageDatasource _swapDatasource;

  WalletTransactionRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required LabelDatasource labelDatasource,
    required WalletDatasource bdkWalletTransactionDatasource,
    required WalletDatasource lwkWalletTransactionDatasource,
    required ElectrumServerStorageDatasource electrumServerStorage,
    required LocalPayjoinDatasource payjoinDatasource,
    required BoltzStorageDatasource swapDatasource,
  }) : _labelDatasource = labelDatasource,
       _walletMetadataDatasource = walletMetadataDatasource,
       _bdkWalletTransactionDatasource = bdkWalletTransactionDatasource,
       _lwkWalletTransactionDatasource = lwkWalletTransactionDatasource,
       _electrumServerStorage = electrumServerStorage,
       _payjoinDatasource = payjoinDatasource,
       _swapDatasource = swapDatasource;

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
    final (walletModels, payjoins, swaps) =
        await (
          _getPublicWalletModels(
            walletId: walletId,
            environment: environment,
            sync: sync,
          ),
          _payjoinDatasource.fetchAll(),
          _swapDatasource.fetchAll(),
        ).wait;

    final walletTransactionLists = await Future.wait(
      walletModels.map((walletModel) async {
        final walletTransactionDatasource =
            walletModel is PublicBdkWalletModel
                ? _bdkWalletTransactionDatasource
                : _lwkWalletTransactionDatasource;

        final walletTransactionModels = await walletTransactionDatasource
            .getTransactions(wallet: walletModel, toAddress: toAddress);

        return await Future.wait(
          walletTransactionModels.map((walletTransactionModel) async {
            final (inputs, outputs, labels) =
                await (
                  Future.wait(
                    walletTransactionModel.inputs.map((inputModel) async {
                      final inputLabels = await _labelDatasource.fetchByEntity(
                        entity: TransactionInputMapper.toEntity(inputModel),
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
                      final outputLabels = await _labelDatasource.fetchByEntity(
                        entity: TransactionOutputMapper.toEntity(outputModel),
                      );
                      List<LabelModel> addressLabels;
                      switch (outputModel) {
                        case LiquidTransactionOutputModel _:
                          final (
                            standardAddressLabels,
                            confidentialAddressLabels,
                          ) = await (
                                _labelDatasource.fetchByEntity(
                                  entity: AddressOnly(
                                    payload: outputModel.standardAddress,
                                  ),
                                ),
                                _labelDatasource.fetchByEntity(
                                  entity: AddressOnly(
                                    payload: outputModel.confidentialAddress,
                                  ),
                                ),
                              ).wait;

                          addressLabels = [
                            ...standardAddressLabels,
                            ...confidentialAddressLabels,
                          ];
                        case BitcoinTransactionOutputModel _:
                          addressLabels = await _labelDatasource.fetchByEntity(
                            entity: AddressOnly(payload: outputModel.address),
                          );
                      }
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
                  _labelDatasource.fetchByEntity(
                    entity: WalletTransactionMapper.toEntity(
                      walletTransactionModel,
                      walletId: '',
                      inputs: [],
                      outputs: [],
                    ),
                  ),
                ).wait;

            Payjoin? payjoin;
            try {
              final payjoinModel = payjoins.firstWhere(
                (payjoin) => payjoin.txId == walletTransactionModel.txId,
              );
              payjoin = payjoinModel.toEntity();
            } catch (_) {
              // Transaction is not a payjoin
              payjoin = null;
            }

            Swap? swap;
            try {
              final swapModel = swaps.firstWhere((swap) {
                switch (swap) {
                  case LnReceiveSwapModel _:
                    return swap.receiveTxid == walletTransactionModel.txId;
                  case LnSendSwapModel _:
                    return swap.sendTxid == walletTransactionModel.txId;
                  case ChainSwapModel _:
                    if (walletTransactionModel.isIncoming) {
                      return swap.receiveTxid == walletTransactionModel.txId;
                    } else {
                      return swap.sendTxid == walletTransactionModel.txId;
                    }
                }
              });
              swap = swapModel.toEntity();
            } catch (_) {
              // Transaction is not a swap
              swap = null;
            }

            return WalletTransactionMapper.toEntity(
              walletTransactionModel,
              walletId: walletModel.id,
              inputs: inputs,
              outputs: outputs,
              labels: labels.map((model) => model.label).toList(),
              payjoin: payjoin,
              swap: swap,
            );
          }).toList(),
        );
      }),
    );

    return walletTransactionLists.expand((tx) => tx).toList();
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

          final walletTransactionDatasource =
              isLiquid
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
