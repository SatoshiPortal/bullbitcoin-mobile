import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/data/models/pending_bitcoin_transaction_model.dart';
import 'package:bb_mobile/features/send/data/pending_bitcoin_transaction_datasource.dart';
import 'package:bb_mobile/features/send/data/pending_bitcoin_transaction_mapper.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/repositories/pending_bitcoin_transaction_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';

class PendingBitcoinTransactionRepositoryImpl
    implements PendingBitcoinTransactionRepository {
  final PendingBitcoinTransactionDatasource _datasource;

  const PendingBitcoinTransactionRepositoryImpl(this._datasource);

  @override
  Future<Result<PendingBitcoinTransaction, SendFailure>> save(
    PendingBitcoinTransaction transaction, {
    int? expectedRevision,
  }) async {
    try {
      final saved = await _datasource.save(
        PendingBitcoinTransactionMapper.toModel(transaction),
        expectedRevision: expectedRevision,
      );
      return Ok(PendingBitcoinTransactionMapper.toEntity(saved));
    } on PendingBitcoinTransactionChangedException catch (_, stackTrace) {
      log.warning(
        'A stale pending Bitcoin transaction update was rejected',
        trace: stackTrace,
      );
      return const Err(SendPendingTransactionChangedFailure());
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to save a pending Bitcoin transaction',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(SendPersistenceFailure());
    }
  }

  @override
  Future<Result<PendingBitcoinTransaction?, SendFailure>> get(String id) async {
    final PendingBitcoinTransactionModel? model;
    try {
      model = await _datasource.get(id);
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to load a pending Bitcoin transaction',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(SendPersistenceFailure());
    }
    if (model == null) return const Ok(null);
    try {
      return Ok(PendingBitcoinTransactionMapper.toEntity(model));
    } on ArgumentError catch (error, stackTrace) {
      log.warning(
        'Loaded an invalid pending Bitcoin transaction',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(SendStoredTransactionInvalidFailure());
    } on FormatException catch (error, stackTrace) {
      log.warning(
        'Loaded an invalid pending Bitcoin transaction',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(SendStoredTransactionInvalidFailure());
    }
  }

  @override
  Stream<Result<PendingBitcoinTransactionSnapshot, SendFailure>> watchWallet(
    String walletId,
  ) async* {
    try {
      await for (final models in _datasource.watchWallet(walletId)) {
        final transactions = <PendingBitcoinTransaction>[];
        var invalidCount = 0;
        for (final model in models) {
          try {
            transactions.add(PendingBitcoinTransactionMapper.toEntity(model));
          } on ArgumentError catch (error, stackTrace) {
            invalidCount++;
            log.warning(
              'Ignored an invalid pending Bitcoin transaction',
              error: error.runtimeType,
              trace: stackTrace,
            );
          } on FormatException catch (error, stackTrace) {
            invalidCount++;
            log.warning(
              'Ignored an invalid pending Bitcoin transaction',
              error: error.runtimeType,
              trace: stackTrace,
            );
          }
        }
        yield Ok(
          PendingBitcoinTransactionSnapshot(
            transactions: transactions,
            invalidCount: invalidCount,
          ),
        );
      }
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to watch pending Bitcoin transactions',
        error: error.runtimeType,
        trace: stackTrace,
      );
      yield const Err(SendPersistenceFailure());
    }
  }

  @override
  Future<Result<void, SendFailure>> delete(
    String id, {
    required int expectedRevision,
  }) async {
    try {
      await _datasource.delete(id, expectedRevision: expectedRevision);
      return const Ok(null);
    } on PendingBitcoinTransactionChangedException catch (_, stackTrace) {
      log.warning(
        'A stale pending Bitcoin transaction delete was rejected',
        trace: stackTrace,
      );
      return const Err(SendPendingTransactionChangedFailure());
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to delete a pending Bitcoin transaction',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(SendPersistenceFailure());
    }
  }
}
