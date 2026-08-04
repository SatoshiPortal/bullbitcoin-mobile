import 'dart:convert';
import 'dart:typed_data';

import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/domain/payjoin_policy.dart';
import 'package:bull_payjoin/src/domain/payjoin_ports.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

const _legacyImportName = 'root-payjoin-v1';

Future<void> importLegacyPayjoinData(
  PayjoinDatabase database,
  PayjoinLegacyDataPort source, {
  PayjoinLogPort? log,
}) async {
  final completed = await (database.select(
    database.payjoinMigrations,
  )..where((row) => row.name.equals(_legacyImportName))).getSingleOrNull();
  if (completed != null) return;

  final snapshot = _quarantineSnapshot(await source.readSnapshot(), log: log);
  final sourceDigest = _snapshotDigest(snapshot);

  await database.transaction(() async {
    final marker = await (database.select(
      database.payjoinMigrations,
    )..where((row) => row.name.equals(_legacyImportName))).getSingleOrNull();
    if (marker != null) return;

    for (final sender in snapshot.senders) {
      await database
          .into(database.payjoinSenders)
          .insert(
            PayjoinSendersCompanion.insert(
              uri: sender.uri,
              isTestnet: sender.isTestnet,
              sender: sender.protocolState,
              walletId: sender.walletId,
              originalPsbt: sender.originalPsbt,
              originalTxId: sender.originalTransactionId,
              amountSat: sender.amountSat,
              createdAt: sender.createdAt,
              expireAfterSec: sender.expireAfterSec,
              proposalPsbt: Value(sender.proposalPsbt),
              txId: Value(sender.transactionId),
              isExpired: sender.isExpired,
              isCompleted: sender.isCompleted,
              isAborted: sender.isAborted,
            ),
          );
    }
    for (final receiver in snapshot.receivers) {
      await database
          .into(database.payjoinReceivers)
          .insert(
            PayjoinReceiversCompanion.insert(
              id: receiver.id,
              address: receiver.address,
              isTestnet: receiver.isTestnet,
              receiver: receiver.protocolState,
              walletId: receiver.walletId,
              pjUri: receiver.payjoinUri,
              maxFeeRateSatPerVb: receiver.maximumFeeRateSatPerVbyte,
              createdAt: receiver.createdAt,
              expireAfterSec: receiver.expireAfterSec,
              originalTxBytes: Value(receiver.originalTransaction),
              originalTxId: Value(receiver.originalTransactionId),
              amountSat: Value(receiver.amountSat),
              proposalPsbt: Value(receiver.proposalPsbt),
              txId: Value(receiver.transactionId),
              isExpired: receiver.isExpired,
              isCompleted: receiver.isCompleted,
              isAborted: receiver.isAborted,
            ),
          );
    }
    await database
        .into(database.payjoinPolicies)
        .insert(
          PayjoinPoliciesCompanion.insert(
            id: const Value(1),
            enabled: snapshot.policy.enabled,
            minimumAmountSat: snapshot.policy.minimumAmountSat,
            sessionLifetimeSeconds: snapshot.policy.sessionLifetimeSeconds,
          ),
        );

    final imported = await _readSnapshot(
      database,
      sourceSchemaVersion: snapshot.sourceSchemaVersion,
    );
    final importedDigest = _snapshotDigest(imported);
    if (importedDigest != sourceDigest ||
        imported.senders.length != snapshot.senders.length ||
        imported.receivers.length != snapshot.receivers.length) {
      throw StateError('Imported Payjoin data did not verify');
    }

    await database
        .into(database.payjoinMigrations)
        .insert(
          PayjoinMigrationsCompanion.insert(
            name: _legacyImportName,
            completedAt: DateTime.now().toUtc(),
            sourceSchemaVersion: snapshot.sourceSchemaVersion,
            senderCount: snapshot.senders.length,
            receiverCount: snapshot.receivers.length,
            verificationDigest: importedDigest,
          ),
        );
  });
}

/// Keeps only the rows that satisfy the import invariants and reports the
/// discarded ones. A single corrupt legacy row must not fail the whole
/// import forever: the caller maps any throw to a permanent
/// PayjoinMigrationFailure, and `reservedOutpoints()` gates coin selection —
/// so one bad row would brick every bitcoin send in the app with no
/// recovery path. Skipped rows are lost for good (the one-shot marker still
/// records the import), which is why every skip is logged. A corrupt policy
/// falls back to the defaults (disabled, conservative bounds) rather than
/// failing: the user can re-enable payjoin in settings.
PayjoinLegacySnapshot _quarantineSnapshot(
  PayjoinLegacySnapshot snapshot, {
  PayjoinLogPort? log,
}) {
  var skippedSenders = 0;
  final senderIds = <String>{};
  final senders = <PayjoinLegacySender>[];
  for (final sender in snapshot.senders) {
    if (sender.uri.trim().isNotEmpty &&
        senderIds.add(sender.uri) &&
        sender.walletId.trim().isNotEmpty &&
        sender.expireAfterSec > 0) {
      senders.add(sender);
    } else {
      skippedSenders++;
    }
  }
  var skippedReceivers = 0;
  final receiverIds = <String>{};
  final receivers = <PayjoinLegacyReceiver>[];
  for (final receiver in snapshot.receivers) {
    if (receiver.id.trim().isNotEmpty &&
        receiverIds.add(receiver.id) &&
        receiver.walletId.trim().isNotEmpty &&
        receiver.expireAfterSec > 0) {
      receivers.add(receiver);
    } else {
      skippedReceivers++;
    }
  }

  var policy = snapshot.policy;
  try {
    PayjoinPolicy(
      enabled: policy.enabled,
      minimumAmount: Sats.fromInt(policy.minimumAmountSat),
      sessionLifetime: Duration(seconds: policy.sessionLifetimeSeconds),
    );
  } catch (_) {
    final defaults = PayjoinPolicy.defaults();
    policy = PayjoinLegacyPolicy(
      enabled: defaults.enabled,
      minimumAmountSat: defaults.minimumAmount.value.toInt(),
      sessionLifetimeSeconds: defaults.sessionLifetime.inSeconds,
    );
    log?.write(
      PayjoinLogEvent(
        level: PayjoinLogLevel.warning,
        code: PayjoinLogCode.migrationFailure,
        error: StateError(
          'Legacy Payjoin policy was invalid; imported defaults instead',
        ),
      ),
    );
  }

  if (skippedSenders > 0 || skippedReceivers > 0) {
    log?.write(
      PayjoinLogEvent(
        level: PayjoinLogLevel.warning,
        code: PayjoinLogCode.migrationFailure,
        error: StateError(
          'Skipped $skippedSenders invalid legacy Payjoin sender(s) and '
          '$skippedReceivers receiver(s) during import',
        ),
      ),
    );
  }

  return PayjoinLegacySnapshot(
    sourceSchemaVersion: snapshot.sourceSchemaVersion,
    senders: senders,
    receivers: receivers,
    policy: policy,
  );
}

Future<PayjoinLegacySnapshot> _readSnapshot(
  PayjoinDatabase database, {
  required int sourceSchemaVersion,
}) async {
  final senders = await database.select(database.payjoinSenders).get();
  final receivers = await database.select(database.payjoinReceivers).get();
  final policy = await (database.select(
    database.payjoinPolicies,
  )..where((row) => row.id.equals(1))).getSingle();
  return PayjoinLegacySnapshot(
    sourceSchemaVersion: sourceSchemaVersion,
    senders: senders
        .map(
          (row) => PayjoinLegacySender(
            uri: row.uri,
            isTestnet: row.isTestnet,
            protocolState: row.sender,
            walletId: row.walletId,
            originalPsbt: row.originalPsbt,
            originalTransactionId: row.originalTxId,
            amountSat: row.amountSat,
            createdAt: row.createdAt,
            expireAfterSec: row.expireAfterSec,
            proposalPsbt: row.proposalPsbt,
            transactionId: row.txId,
            isExpired: row.isExpired,
            isCompleted: row.isCompleted,
            isAborted: row.isAborted,
          ),
        )
        .toList(),
    receivers: receivers
        .map(
          (row) => PayjoinLegacyReceiver(
            id: row.id,
            address: row.address,
            isTestnet: row.isTestnet,
            protocolState: row.receiver,
            walletId: row.walletId,
            payjoinUri: row.pjUri,
            maximumFeeRateSatPerVbyte: row.maxFeeRateSatPerVb,
            createdAt: row.createdAt,
            expireAfterSec: row.expireAfterSec,
            originalTransaction: row.originalTxBytes,
            originalTransactionId: row.originalTxId,
            amountSat: row.amountSat,
            proposalPsbt: row.proposalPsbt,
            transactionId: row.txId,
            isExpired: row.isExpired,
            isCompleted: row.isCompleted,
            isAborted: row.isAborted,
          ),
        )
        .toList(),
    policy: PayjoinLegacyPolicy(
      enabled: policy.enabled,
      minimumAmountSat: policy.minimumAmountSat,
      sessionLifetimeSeconds: policy.sessionLifetimeSeconds,
    ),
  );
}

String _snapshotDigest(PayjoinLegacySnapshot snapshot) {
  final sink = BytesBuilder(copy: false);
  final senders = [...snapshot.senders]..sort((a, b) => a.uri.compareTo(b.uri));
  final receivers = [...snapshot.receivers]
    ..sort((a, b) => a.id.compareTo(b.id));
  for (final sender in senders) {
    _writeText(sink, 'sender');
    _writeText(sink, sender.uri);
    _writeBool(sink, sender.isTestnet);
    _writeText(sink, sender.protocolState);
    _writeText(sink, sender.walletId);
    _writeText(sink, sender.originalPsbt);
    _writeText(sink, sender.originalTransactionId);
    _writeInt(sink, sender.amountSat);
    _writeInt(sink, sender.createdAt);
    _writeInt(sink, sender.expireAfterSec);
    _writeText(sink, sender.proposalPsbt);
    _writeText(sink, sender.transactionId);
    _writeBool(sink, sender.isExpired);
    _writeBool(sink, sender.isCompleted);
    _writeBool(sink, sender.isAborted);
  }
  for (final receiver in receivers) {
    _writeText(sink, 'receiver');
    _writeText(sink, receiver.id);
    _writeText(sink, receiver.address);
    _writeBool(sink, receiver.isTestnet);
    _writeText(sink, receiver.protocolState);
    _writeText(sink, receiver.walletId);
    _writeText(sink, receiver.payjoinUri);
    _writeInt(sink, receiver.maximumFeeRateSatPerVbyte.toInt());
    _writeInt(sink, receiver.createdAt);
    _writeInt(sink, receiver.expireAfterSec);
    _writeBytes(sink, receiver.originalTransaction);
    _writeText(sink, receiver.originalTransactionId);
    _writeInt(sink, receiver.amountSat);
    _writeText(sink, receiver.proposalPsbt);
    _writeText(sink, receiver.transactionId);
    _writeBool(sink, receiver.isExpired);
    _writeBool(sink, receiver.isCompleted);
    _writeBool(sink, receiver.isAborted);
  }
  _writeText(sink, 'policy');
  _writeBool(sink, snapshot.policy.enabled);
  _writeInt(sink, snapshot.policy.minimumAmountSat);
  _writeInt(sink, snapshot.policy.sessionLifetimeSeconds);
  return sha256.convert(sink.takeBytes()).toString();
}

void _writeText(BytesBuilder sink, String? value) {
  _writeValue(sink, 1, value == null ? null : utf8.encode(value));
}

void _writeBytes(BytesBuilder sink, Uint8List? value) {
  _writeValue(sink, 2, value);
}

void _writeInt(BytesBuilder sink, int? value) {
  if (value == null) return _writeValue(sink, 3, null);
  final bytes = ByteData(8)..setInt64(0, value, Endian.big);
  _writeValue(sink, 3, bytes.buffer.asUint8List());
}

void _writeBool(BytesBuilder sink, bool value) {
  _writeValue(sink, 4, Uint8List.fromList([value ? 1 : 0]));
}

void _writeValue(BytesBuilder sink, int type, List<int>? value) {
  sink.addByte(type);
  if (value == null) {
    sink.addByte(0);
    return;
  }
  sink.addByte(1);
  final length = ByteData(4)..setUint32(0, value.length, Endian.big);
  sink.add(length.buffer.asUint8List());
  sink.add(value);
}
