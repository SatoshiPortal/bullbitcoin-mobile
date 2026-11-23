import 'package:bb_mobile/features/transactions/data/wallet_history_datasource.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:bull_logger/bull_logger.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/transactions/data/mappers/transaction_input_mapper.dart';
import 'package:bb_mobile/features/transactions/data/mappers/transaction_output_mapper.dart';
import 'package:bb_mobile/features/transactions/data/mappers/wallet_transaction_mapper.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/transactions/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/repositories/wallet_transaction_repository.dart';
import 'package:labels/labels.dart';

class WalletTransactionRepositoryImpl implements WalletTransactionRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final Labels _labelsFacade;
  final WalletHistoryDatasource _history;
  final Future<void> Function(WalletMetadataModel) _synchronize;

  WalletTransactionRepositoryImpl({
    required this._walletMetadataDatasource,
    required this._labelsFacade,
    required this._history,
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
    final walletKeys = await _getWalletKeys(
      walletId: walletId,
      environment: environment,
      sync: sync,
    );

    final walletTransactions = await _getWalletTransactions(
      txId: txId,
      walletKeys: walletKeys,
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

  Future<List<Label>> _fetchLabels(String reference) async =>
      (await _labelsFacade.fetch(reference: reference))
          .fold((labels) => labels, (_) => const <Label>[]);

  Future<List<WalletTransaction>> _getWalletTransactions({
    required List<WalletKey> walletKeys,
    String? txId,
    String? toAddress,
  }) async {
    final walletTransactionLists = await Future.wait(
      walletKeys.map((key) async {
        final walletTransactionModels = await _history.getTransactions(
          key: key,
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
                  final inputLabels = await _fetchLabels(inputModel.labelRef);
                  return TransactionInputMapper.toEntity(
                    inputModel,
                    labels: inputLabels.map((label) => label.label).toList(),
                  );
                }),
              ),
              Future.wait(
                walletTransactionModel.outputs.map((outputModel) async {
                  final outputLabels = await _fetchLabels(outputModel.labelRef);
                  final outputModelAddress = outputModel.address;
                  final addressLabels = <Label>[];
                  if (outputModelAddress != null) {
                    final rows = await _fetchLabels(outputModelAddress);
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
              _fetchLabels(walletTransactionModel.txId),
            ).wait;

            return WalletTransactionMapper.toEntity(
              walletTransactionModel,
              walletId: key.id,
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

  Future<List<WalletKey>> _getWalletKeys({
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
    if (sync) {
      await Future.wait(filteredWalletsMetadata.map(_synchronize));
    }

    return [
      for (final metadata in filteredWalletsMetadata)
        WalletKey(id: metadata.id, network: metadata.network.shared),
    ];
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
