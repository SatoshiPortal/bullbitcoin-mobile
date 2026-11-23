import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show WalletKey, SyncFailure;

import '../domain/transaction_failure.dart';
import '../domain/entities/transaction_input.dart';
import '../domain/entities/transaction_output.dart';

import 'package:transactions/src/data/wallet_history_datasource.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:preferences/preferences.dart';
import 'package:transactions/src/data/mappers/transaction_input_mapper.dart';
import 'package:transactions/src/data/mappers/transaction_output_mapper.dart';
import 'package:transactions/src/data/mappers/wallet_transaction_mapper.dart';
import 'package:transactions/src/domain/entities/wallet_transaction.dart';
import 'package:transactions/src/domain/repositories/wallet_transaction_repository.dart';
import 'package:labels/labels.dart';

class WalletTransactionRepositoryImpl implements WalletTransactionRepository {
  final WalletInventory _inventory;
  final Labels _labelsFacade;
  final WalletHistoryDatasource _history;
  final Future<Result<void, SyncFailure>> Function(WalletKey) _synchronize;

  WalletTransactionRepositoryImpl({
    required this._inventory,
    required this._labelsFacade,
    required this._history,
    required this._synchronize,
  });

  @override
  Future<Result<List<WalletTransaction>, TransactionFailure>>
  getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  }) async {
    try {
      final keys = await _getWalletKeys(
        walletId: walletId,
        environment: environment,
      );
      if (keys case Err(:final failure)) return Err(failure);
      if (keys case Ok(value: final walletKeys)) {
        if (sync) {
          final results = await Future.wait(walletKeys.map(_synchronize));
          for (final result in results) {
            if (result case Err(:final failure)) {
              return Err(_syncFailure(failure));
            }
          }
        }
        return await _getWalletTransactions(
          txId: txId,
          walletKeys: walletKeys,
          toAddress: toAddress,
        );
      }
      return const Err(TransactionAggregationFailure());
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Wallet history unavailable: ${error.runtimeType}',
        trace: stackTrace,
      );
      return const Err(TransactionAggregationFailure());
    }
  }

  static TransactionFailure _syncFailure(SyncFailure failure) =>
      TransactionAggregationFailure('Wallet history: ${failure.logCode}');

  @override
  Future<Result<WalletTransaction?, TransactionFailure>> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  }) async {
    final transactions = await getWalletTransactions(
      txId: txId,
      walletId: walletId,
      sync: sync,
    );

    return transactions.map((value) => value.firstOrNull);
  }

  Future<List<Label>> _fetchLabels(String reference) async =>
      (await _labelsFacade.fetch(reference: reference))
          .fold((labels) => labels, (_) => const <Label>[]);

  Future<Result<List<WalletTransaction>, TransactionFailure>>
  _getWalletTransactions({
    required List<WalletKey> walletKeys,
    String? txId,
    String? toAddress,
  }) async {
    final walletTransactionLists = await Future.wait(
      walletKeys.map((key) async {
        final loaded = await _history.getTransactions(
          key: key,
          toAddress: toAddress,
        );

        if (loaded case Err(:final failure)) {
          return Err<List<WalletTransaction>, TransactionFailure>(
            _syncFailure(failure),
          );
        }
        final walletTransactionModels = switch (loaded) {
          Ok(:final value) => value,
          Err() => const [],
        };
        return Ok<List<WalletTransaction>, TransactionFailure>(
          await Future.wait(
            walletTransactionModels
                .where((model) => txId == null || model.txId == txId)
                .map((walletTransactionModel) async {
                  final (inputs, outputs, labels) = await (
                    Future.wait<TransactionInput>(
                      walletTransactionModel.inputs.map((inputModel) async {
                        final inputLabels = await _fetchLabels(
                          inputModel.labelRef,
                        );
                        return TransactionInputMapper.toEntity(
                          inputModel,
                          labels: inputLabels
                              .map((label) => label.label)
                              .toList(),
                        );
                      }),
                    ),
                    Future.wait<TransactionOutput>(
                      walletTransactionModel.outputs.map((outputModel) async {
                        final outputLabels = await _fetchLabels(
                          outputModel.labelRef,
                        );
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
                }),
          ),
        );
      }),
    );

    final transactions = <WalletTransaction>[];
    for (final result in walletTransactionLists) {
      switch (result) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          transactions.addAll(value);
      }
    }
    return Ok(transactions);
  }

  Future<Result<List<WalletKey>, TransactionFailure>> _getWalletKeys({
    required String? walletId,
    required Environment? environment,
  }) async {
    final env = environment?.networkEnv;
    if (walletId != null) {
      return switch (await _inventory.readWallet(walletId)) {
        Ok(:final value) => Ok([
          if (env == null || env == value.network.env)
            WalletKey(id: value.id, network: value.network),
        ]),
        Err(failure: WalletRegistrationNotFoundFailure()) => const Err(
          TransactionNotFoundFailure(),
        ),
        Err(:final failure) => Err(_inventoryFailure(failure)),
      };
    }
    final selections = await Future.wait([
      for (final network in <Network>[
        ...BitcoinNetwork.values,
        ...LiquidNetwork.values,
      ])
        if (network.env != NetworkEnv.signet &&
            (env == null || env == network.env))
          _inventory.walletsForNetwork(network),
    ]);
    final keys = <WalletKey>[];
    for (final selection in selections) {
      switch (selection) {
        case Ok(:final value):
          keys.addAll(
            value.wallets.map(
              (wallet) => WalletKey(id: wallet.id, network: wallet.network),
            ),
          );
        case Err(failure: UnreadableWalletFailure()):
          log.warning('Skipping an unreadable wallet inventory selection');
        case Err(:final failure):
          return Err(_inventoryFailure(failure));
      }
    }
    return Ok(keys);
  }

  static TransactionFailure _inventoryFailure(SecretFailure failure) =>
      TransactionAggregationFailure('Wallet inventory: ${failure.runtimeType}');
}
