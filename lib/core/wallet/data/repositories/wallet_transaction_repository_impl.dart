import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/transaction_input_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/transaction_output_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_transaction_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart'
    show WalletSourceKey, WalletSourceOperationCoordinator;

class WalletTransactionRepositoryImpl implements WalletTransactionRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final LabelsFacade _labelsFacade;
  final BdkWalletDatasource _bdkWalletTransactionDatasource;
  final LwkWalletDatasource _lwkWalletTransactionDatasource;
  // TODO: We should not pass a port into a repository, this is a dirty hack for now
  //  the syncing should be extracted from fetching the data
  final ElectrumServersPort _serversPort;
  final WalletSourceOperationCoordinator _coordinator;

  WalletTransactionRepositoryImpl({
    required this._walletMetadataDatasource,
    required this._labelsFacade,
    required this._bdkWalletTransactionDatasource,
    required this._lwkWalletTransactionDatasource,
    required this._serversPort,
    required WalletSourceOperationCoordinator coordinator,
  }) : _coordinator = coordinator; // ignore: prefer_initializing_formals

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
    );

    final walletTransactions = await _getWalletTransactions(
      txId: txId,
      walletModels: walletModels,
      toAddress: toAddress,
      sync: sync,
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
    required bool sync,
  }) async {
    final walletTransactionModelsByWallet = await Future.wait(
      walletModels.map((walletModel) async {
        return walletModel is PublicBdkWalletModel
            ? await _getBdkWalletTransactionModels(
                wallet: walletModel,
                txId: txId,
                toAddress: toAddress,
                sync: sync,
              )
            : await _getLwkWalletTransactionModels(
                wallet: walletModel as PublicLwkWalletModel,
                txId: txId,
                toAddress: toAddress,
                sync: sync,
              );
      }),
    );

    final labelsByReference = <String, List<Label>>{};
    for (final label in await _labelsFacade.fetchAll()) {
      labelsByReference.putIfAbsent(label.reference, () => []).add(label);
    }

    final walletTransactionLists = await Future.wait(
      walletTransactionModelsByWallet.indexed.map((entry) async {
        final (walletIndex, walletTransactionModels) = entry;
        final walletModel = walletModels[walletIndex];
        return Future.wait(
          walletTransactionModels.map((walletTransactionModel) async {
            final (inputs, outputs, labels) = await (
              Future.wait(
                walletTransactionModel.inputs.map((inputModel) async {
                  final inputLabels =
                      labelsByReference[inputModel.labelRef] ?? const <Label>[];
                  return TransactionInputMapper.toEntity(
                    inputModel,
                    labels: inputLabels.map((label) => label.label).toList(),
                  );
                }),
              ),
              Future.wait(
                walletTransactionModel.outputs.map((outputModel) async {
                  final outputLabels =
                      labelsByReference[outputModel.labelRef] ??
                      const <Label>[];
                  final outputModelAddress = outputModel.address;
                  final addressLabels = outputModelAddress == null
                      ? const <Label>[]
                      : labelsByReference[outputModelAddress] ??
                            const <Label>[];

                  return TransactionOutputMapper.toEntity(
                    outputModel,
                    labels: outputLabels,
                    addressLabels: addressLabels,
                    //isFrozen: isFrozen, // Todo: check if frozen
                  );
                }),
              ),
              Future.value(
                labelsByReference[walletTransactionModel.txId] ??
                    const <Label>[],
              ),
            ).wait;

            return WalletTransactionMapper.toEntity(
              walletTransactionModel,
              walletId: walletModel.id,
              inputs: inputs,
              outputs: outputs,
              labels: labels,
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

    return walletModels;
  }

  Future<List<WalletTransactionModel>> _getBdkWalletTransactionModels({
    required PublicBdkWalletModel wallet,
    String? txId,
    String? toAddress,
    required bool sync,
  }) {
    return _coordinator.runExclusive(_sourceKey(wallet), (_) async {
      if (sync) {
        await _serversPort.runWithFallback<void>(
          network: ElectrumServerNetwork.fromEnvironment(
            isTestnet: wallet.isTestnet,
            isLiquid: false,
          ),
          operation: (connection) => _bdkWalletTransactionDatasource.sync(
            wallet: wallet,
            electrumServer: connection,
          ),
        );
      }
      return _bdkWalletTransactionDatasource.getTransactions(
        wallet: wallet,
        txId: txId,
        toAddress: toAddress,
      );
    });
  }

  Future<List<WalletTransactionModel>> _getLwkWalletTransactionModels({
    required PublicLwkWalletModel wallet,
    String? txId,
    String? toAddress,
    required bool sync,
  }) {
    return _coordinator.runExclusive(_sourceKey(wallet), (_) async {
      if (sync) {
        await _serversPort.runWithFallback<void>(
          network: ElectrumServerNetwork.fromEnvironment(
            isTestnet: wallet.isTestnet,
            isLiquid: true,
          ),
          operation: (connection) => _lwkWalletTransactionDatasource.sync(
            wallet: wallet,
            electrumServer: connection,
          ),
        );
      }
      final transactions = await _lwkWalletTransactionDatasource
          .getTransactions(wallet: wallet, txId: txId, toAddress: toAddress);
      if (txId == null) return transactions;
      return transactions
          .where((transaction) => transaction.txId == txId)
          .toList();
    });
  }

  WalletSourceKey _sourceKey(WalletModel wallet) => WalletSourceKey(
    wallet.id,
    wallet is PublicLwkWalletModel ? 'liquid' : 'bitcoin',
    wallet.isTestnet ? 'testnet' : 'mainnet',
  );
}
