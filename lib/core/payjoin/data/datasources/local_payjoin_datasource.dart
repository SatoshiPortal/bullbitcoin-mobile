import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

class LocalPayjoinDatasource {
  final SqliteDatabase _db;

  LocalPayjoinDatasource({required this._db});

  Future<void> storeReceiver(PayjoinReceiverModel receiver) async {
    try {
      final row = receiver.toSqlite();
      await _db.into(_db.payjoinReceivers).insertOnConflictUpdate(row);
    } catch (e) {
      throw CreateReceiverException('$e');
    }
  }

  Future<void> storeSender(PayjoinSenderModel sender) async {
    try {
      final row = sender.toSqlite();
      await _db.into(_db.payjoinSenders).insertOnConflictUpdate(row);
    } catch (e) {
      throw CreateSenderException('$e');
    }
  }

  Future<PayjoinReceiverModel?> fetchReceiver(String id) async {
    final receiver = await _db.managers.payjoinReceivers
        .filter((f) => f.id(id))
        .getSingleOrNull();

    if (receiver == null) return null;

    return PayjoinModel.fromReceiverTable(receiver) as PayjoinReceiverModel;
  }

  Future<PayjoinSenderModel?> fetchSender(String uri) async {
    final sender = await _db.managers.payjoinSenders
        .filter((f) => f.uri(uri))
        .getSingleOrNull();

    if (sender == null) return null;

    return PayjoinModel.fromSenderTable(sender) as PayjoinSenderModel;
  }

  Future<void> deleteReceiver(String id) async {
    await _db.managers.payjoinReceivers.filter((f) => f.id(id)).delete();
  }

  Future<List<PayjoinModel>> fetchAll({
    String? walletId,
    bool onlyUnfinished = false,
    Environment? environment,
  }) async {
    final isTestnet = environment?.isTestnet;

    final receiverFilter = _db.managers.payjoinReceivers.filter((row) {
      Expression<bool> expr = const Constant(true); // identity

      if (onlyUnfinished) {
        // isAborted is a terminal outcome too (we already broadcast the
        // original in its place) — excluded here for the same reason
        // isCompleted/isExpired are, otherwise an aborted session would
        // keep being "resumed" on every app start.
        expr =
            expr &
            row.isExpired.equals(false) &
            row.isCompleted.equals(false) &
            row.isAborted.equals(false);
      }

      if (walletId != null) {
        expr = expr & row.walletId.equals(walletId);
      }

      if (isTestnet != null) {
        expr = expr & row.isTestnet.equals(isTestnet);
      }

      return expr;
    });

    final senderFilter = _db.managers.payjoinSenders.filter((row) {
      Expression<bool> expr = const Constant(true);

      if (onlyUnfinished) {
        expr =
            expr &
            row.isExpired.equals(false) &
            row.isCompleted.equals(false) &
            row.isAborted.equals(false);
      }

      if (walletId != null) {
        expr = expr & row.walletId.equals(walletId);
      }

      if (isTestnet != null) {
        expr = expr & row.isTestnet.equals(isTestnet);
      }

      return expr;
    });

    final (receivers, senders) = await (
      receiverFilter.get(),
      senderFilter.get(),
    ).wait;

    return [
      ...receivers.map(PayjoinModel.fromReceiverTable),
      ...senders.map(PayjoinModel.fromSenderTable),
    ];
  }

  /// Fetches the payjoin session(s) a transaction id belongs to, matching
  /// BOTH the payjoin transaction id and the original transaction id. The
  /// original matters as much as the payjoin one: an aborted session (we
  /// broadcast the original instead of completing a real payjoin — see
  /// PayjoinStatus.aborted) has no [txId] at all, so the transaction that
  /// actually hit the chain IS the original — matching only [txId] made
  /// that transaction's details lose its payjoin context entirely, hiding
  /// the very "aborted" outcome the status exists to communicate. The
  /// transactions LIST already joins on both ids
  /// (GetTransactionsUsecase); this keeps the details path consistent.
  Future<List<PayjoinModel>> fetchByTxId(String txId) async {
    final (receivers, senders) = await (
      _db.managers.payjoinReceivers
          .filter((f) => f.txId(txId) | f.originalTxId(txId))
          .get(),
      _db.managers.payjoinSenders
          .filter((f) => f.txId(txId) | f.originalTxId(txId))
          .get(),
    ).wait;

    return [
      ...receivers.map((receiver) => PayjoinModel.fromReceiverTable(receiver)),
      ...senders.map((sender) => PayjoinModel.fromSenderTable(sender)),
    ];
  }

  Future<List<PayjoinReceiverModel>> fetchReceivers({
    bool onlyOngoing = false,
  }) async {
    final receiversTable = _db.managers.payjoinReceivers;
    List<PayjoinReceiverRow> receivers;
    if (onlyOngoing) {
      receivers = await receiversTable
          .filter((f) => f.isExpired(false))
          .filter((f) => f.isCompleted(false))
          .filter((f) => f.isAborted(false))
          .get();
    } else {
      receivers = await receiversTable.get();
    }

    return receivers
        .map(
          (receiver) =>
              PayjoinModel.fromReceiverTable(receiver) as PayjoinReceiverModel,
        )
        .toList();
  }

  Future<List<PayjoinSenderModel>> fetchSenders({
    bool onlyOngoing = false,
  }) async {
    final sendersTable = _db.managers.payjoinSenders;
    List<PayjoinSenderRow> senders;

    if (onlyOngoing) {
      senders = await sendersTable
          .filter((f) => f.isExpired(false))
          .filter((f) => f.isCompleted(false))
          .filter((f) => f.isAborted(false))
          .get();
    } else {
      senders = await sendersTable.get();
    }

    return senders
        .map(
          (sender) =>
              PayjoinModel.fromSenderTable(sender) as PayjoinSenderModel,
        )
        .toList();
  }

  Future<void> update(PayjoinModel payjoin) async {
    try {
      if (payjoin is PayjoinReceiverModel) {
        await storeReceiver(payjoin);
      } else if (payjoin is PayjoinSenderModel) {
        await storeSender(payjoin);
      }
    } catch (e) {
      throw UpdateException('$e');
    }
  }
}

class CreateReceiverException extends BullException {
  CreateReceiverException(super.message);
}

class CreateSenderException extends BullException {
  CreateSenderException(super.message);
}

class UpdateException extends BullException {
  UpdateException(super.message);
}
