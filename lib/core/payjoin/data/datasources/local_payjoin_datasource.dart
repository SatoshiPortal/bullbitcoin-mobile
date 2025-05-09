import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';

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
    final receiver =
        await _db.managers.payjoinReceivers
            .filter((f) => f.id(id))
            .getSingleOrNull();

    if (receiver == null) return null;

    return PayjoinModel.fromReceiverTable(receiver) as PayjoinReceiverModel;
  }

  Future<PayjoinSenderModel?> fetchSender(String uri) async {
    final sender =
        await _db.managers.payjoinSenders
            .filter((f) => f.uri(uri))
            .getSingleOrNull();

    if (sender == null) return null;

    return PayjoinModel.fromSenderTable(sender) as PayjoinSenderModel;
  }

  Future<List<PayjoinModel>> fetchAll({bool onlyUnfinished = false}) async {
    List<PayjoinReceiverRow> receivers;
    List<PayjoinSenderRow> senders;

    if (onlyUnfinished) {
      receivers =
          await _db.managers.payjoinReceivers
              .filter((f) => f.isExpired(false))
              .filter((f) => f.isCompleted(false))
              .get();
      senders =
          await _db.managers.payjoinSenders
              .filter((f) => f.isExpired(false))
              .filter((f) => f.isCompleted(false))
              .get();
    } else {
      (receivers, senders) =
          await (
            _db.managers.payjoinReceivers.get(),
            _db.managers.payjoinSenders.get(),
          ).wait;
    }

    return [
      ...receivers.map((receiver) => PayjoinModel.fromReceiverTable(receiver)),
      ...senders.map((sender) => PayjoinModel.fromSenderTable(sender)),
    ];
  }

  Future<List<PayjoinModel>> fetchByTxId(String txId) async {
    final (receivers, senders) =
        await (
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
      receivers =
          await receiversTable
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
      senders =
          await sendersTable
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

class CreateReceiverException implements Exception {
  final String message;

  CreateReceiverException(this.message);
}

class CreateSenderException implements Exception {
  final String message;

  CreateSenderException(this.message);
}

class UpdateException implements Exception {
  final String message;

  UpdateException(this.message);
}
