import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/transaction_input_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/transaction_output_mapper.dart';
import 'package:bb_mobile/features/wallet/data/wallet_transaction_mapper.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class WalletTransactionRepositoryImpl implements WalletTransactionRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final LabelsFacade _labelsFacade;
  final BdkWalletDatasource _bdkWalletTransactionDatasource;
  final LwkWalletDatasource _lwkWalletTransactionDatasource;
  final Future<void> Function(WalletMetadataModel) _synchronize;

  WalletTransactionRepositoryImpl({
    required this._walletMetadataDatasource,
    required this._labelsFacade,
    required this._bdkWalletTransactionDatasource,
    required this._lwkWalletTransactionDatasource,
    required this._synchronize,
  });

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
        final walletTransactionModels = walletModel is PublicBdkWalletModel
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
            final (inputs, outputs, labels) = await (
              Future.wait(
                walletTransactionModel.inputs.map((inputModel) async {
                  final inputLabels = await _labelsFacade.fetchByReference(
                    inputModel.labelRef,
                  );
                  return TransactionInputMapper.toEntity(
                    inputModel,
                    labels: inputLabels.map((label) => label.label).toList(),
                  );
                }),
              ),
              Future.wait(
                walletTransactionModel.outputs.map((outputModel) async {
                  final outputLabels = await _labelsFacade.fetchByReference(
                    outputModel.labelRef,
                  );
                  final outputModelAddress = outputModel.address;
                  final addressLabels = <Label>[];
                  if (outputModelAddress != null) {
                    final rows = await _labelsFacade.fetchByReference(
                      outputModelAddress,
                    );
                    addressLabels.addAll(rows);
                  }

                  return TransactionOutputMapper.toEntity(
                    outputModel,
                    labels: outputLabels,
                    addressLabels: addressLabels,
                    //isFrozen: isFrozen, // Todo: check if frozen
                  );
                }),
              ),
              _labelsFacade.fetchByReference(walletTransactionModel.txId),
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

    final filteredWalletsMetadata =
        _readableNetworks(walletsMetadata, isRequested: walletId != null)
            .where(
              (metadata) =>
                  environment == null ||
                  environment.networkEnv == metadata.network.environment,
            )
            .toList();
    final walletModels = filteredWalletsMetadata
        .map(
          (metadata) => metadata.isBitcoin
              ? WalletModel.publicBdk(
                  externalDescriptor: metadata.externalPublicDescriptor,
                  internalDescriptor: metadata.internalPublicDescriptor,
                  network: metadata.network,
                  id: metadata.id,
                )
              : WalletModel.publicLwk(
                  combinedCtDescriptor: metadata.externalPublicDescriptor,
                  network: metadata.network,
                  id: metadata.id,
                ),
        )
        .toList();

    if (sync) {
      await Future.wait(filteredWalletsMetadata.map(_synchronize));
    }

    return walletModels;
  }

  /// A row whose stored network cannot be decoded (left `unresolved` by the
  /// schema 16 backfill, or written by another build) is skipped when listing
  /// every wallet, so it cannot hide the others' transactions. A wallet asked
  /// for by id still fails: its transactions cannot be read.
  static List<WalletMetadataModel> _readableNetworks(
    List<WalletMetadataModel> rows, {
    required bool isRequested,
  }) {
    final readable = <WalletMetadataModel>[];
    for (final row in rows) {
      try {
        row.network;
        readable.add(row);
      } on FormatException {
        if (isRequested) rethrow;
        log.warning(
          'Wallet transactions skip a wallet with an unreadable network '
          'network_code=${row.networkCode}',
        );
      }
    }
    return readable;
  }
}
