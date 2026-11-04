import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/transactions/data/mappers/transaction_input_mapper.dart';
import 'package:bb_mobile/features/transactions/data/mappers/transaction_output_mapper.dart';
import 'package:bb_mobile/features/transactions/data/mappers/wallet_transaction_mapper.dart';
import 'package:bb_mobile/features/transactions/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class WalletTransactionRepositoryImpl implements WalletTransactionRepository {
  final WalletCatalogPort _walletMetadataDatasource;
  final LabelsFacade _labelsFacade;
  final WalletTransactionReader _reader;

  WalletTransactionRepositoryImpl({
    required this._walletMetadataDatasource,
    required this._labelsFacade,
    required this._reader,
  });

  @override
  Future<List<WalletTransaction>> getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  }) async {
    final walletModels = await _getWallets(
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
    required List<WalletMetadata> walletModels,
    String? txId,
    String? toAddress,
    required bool sync,
  }) async {
    final walletTransactionModelsByWallet = await Future.wait(
      walletModels.map((walletModel) async {
        return _reader.read(
          wallet: walletModel,
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

  Future<List<WalletMetadata>> _getWallets({
    String? walletId,
    Environment? environment,
  }) async {
    List<WalletMetadata> walletsMetadata;
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
    return filteredWalletsMetadata.toList();
  }
}
