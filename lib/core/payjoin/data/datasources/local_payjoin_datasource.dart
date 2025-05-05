import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

class LocalPayjoinDatasource {
  final SqliteDatabase _db;

  LocalPayjoinDatasource({required SqliteDatabase db}) : _db = db;

  Future<void> storeReceiver(PayjoinReceiverModel receiver) async {
    try {
      await _db.managers.payjoinReceivers.create(
        (r) => r(
          id: receiver.id,
          address: receiver.address,
          isTestnet: receiver.isTestnet,
          receiver: receiver.receiver,
          walletId: receiver.walletId,
          pjUri: receiver.pjUri,
          maxFeeRateSatPerVb: receiver.maxFeeRateSatPerVb,
          createdAt: receiver.createdAt,
          expireAfterSec: receiver.expireAfterSec,
          originalTxBytes: Value(receiver.originalTxBytes),
          originalTxId: Value(receiver.originalTxId),
          amountSat: Value(receiver.amountSat),
          proposalPsbt: Value(receiver.proposalPsbt),
          txId: Value(receiver.txId),
          isExpired: receiver.isExpired,
          isCompleted: receiver.isCompleted,
        ),
      );
    } catch (e) {
      throw CreateReceiverException('$e');
    }
  }

  Future<void> storeSender(PayjoinSenderModel sender) async {
    try {
      await _db.managers.payjoinSenders.create(
        (s) => s(
          uri: sender.uri,
          isTestnet: sender.isTestnet,
          sender: sender.sender,
          walletId: sender.walletId,
          originalPsbt: sender.originalPsbt,
          originalTxId: sender.originalTxId,
          createdAt: sender.createdAt,
          expireAfterSec: sender.expireAfterSec,
          proposalPsbt: Value(sender.proposalPsbt),
          txId: Value(sender.txId),
          isExpired: sender.isExpired,
          isCompleted: sender.isCompleted,
        ),
      );
    } catch (e) {
      throw CreateSenderException('$e');
    }
  }

  Future<PayjoinReceiverModel?> fetchReceiver(String id) async {
    final receiver =
        await _db.managers.payjoinReceivers
            .filter((f) => f.id(id))
            .getSingleOrNull();

    if (receiver == null) {
      return null;
    }

    return PayjoinModel.fromReceiverTable(receiver) as PayjoinReceiverModel;
  }

  Future<PayjoinSenderModel?> fetchSender(String uri) async {
    final sender =
        await _db.managers.payjoinSenders
            .filter((f) => f.uri(uri))
            .getSingleOrNull();

    if (sender == null) {
      return null;
    }

    return PayjoinModel.fromSenderTable(sender) as PayjoinSenderModel;
  }

  Future<List<PayjoinModel>> fetchAll({bool onlyOngoing = false}) async {
    List<PayjoinReceiverRow> receivers;
    List<PayjoinSenderRow> senders;

    if (onlyOngoing) {
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
        await _db.managers.payjoinReceivers
            .filter((f) => f.id(payjoin.id))
            .update(
              (r) => r(
                id: Value(payjoin.id),
                address: Value(payjoin.address),
                isTestnet: Value(payjoin.isTestnet),
                receiver: Value(payjoin.receiver),
                walletId: Value(payjoin.walletId),
                pjUri: Value(payjoin.pjUri),
                maxFeeRateSatPerVb: Value(payjoin.maxFeeRateSatPerVb),
                createdAt: Value(payjoin.createdAt),
                expireAfterSec: Value(payjoin.expireAfterSec),
                originalTxBytes: Value(payjoin.originalTxBytes),
                originalTxId: Value(payjoin.originalTxId),
                amountSat: Value(payjoin.amountSat),
                proposalPsbt: Value(payjoin.proposalPsbt),
                txId: Value(payjoin.txId),
                isExpired: Value(payjoin.isExpired),
                isCompleted: Value(payjoin.isCompleted),
              ),
            );
      } else if (payjoin is PayjoinSenderModel) {
        await _db.managers.payjoinSenders
            .filter((f) => f.uri(payjoin.uri))
            .update(
              (s) => s(
                uri: Value(payjoin.uri),
                isTestnet: Value(payjoin.isTestnet),
                sender: Value(payjoin.sender),
                walletId: Value(payjoin.walletId),
                originalPsbt: Value(payjoin.originalPsbt),
                originalTxId: Value(payjoin.originalTxId),
                createdAt: Value(payjoin.createdAt),
                expireAfterSec: Value(payjoin.expireAfterSec),
                proposalPsbt: Value(payjoin.proposalPsbt),
                txId: Value(payjoin.txId),
                isExpired: Value(payjoin.isExpired),
                isCompleted: Value(payjoin.isCompleted),
              ),
            );
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
