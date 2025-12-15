import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:drift/drift.dart';

class LocalPayjoinDatasource {
  final SqliteDatabase _db;

  LocalPayjoinDatasource({required SqliteDatabase db}) : _db = db;

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

  Future<List<PayjoinModel>> fetchAll({
    String? walletId,
    bool onlyUnfinished = false,
    Environment? environment,
  }) async {
    final isTestnet = environment?.isTestnet;

    final receiverFilter = _db.managers.payjoinReceivers.filter((row) {
      Expression<bool> expr = const Constant(true); // identity

      if (onlyUnfinished) {
        expr =
            expr & row.isExpired.equals(false) & row.isCompleted.equals(false);
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
            expr & row.isExpired.equals(false) & row.isCompleted.equals(false);
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

  Future<List<PayjoinModel>> fetchByTxId(String txId) async {
    final (receivers, senders) = await (
      _db.managers.payjoinReceivers.filter((f) => f.txId(txId)).get(),
      _db.managers.payjoinSenders.filter((f) => f.txId(txId)).get(),
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
