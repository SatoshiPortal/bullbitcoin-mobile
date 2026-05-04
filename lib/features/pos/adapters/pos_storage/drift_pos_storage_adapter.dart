import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_storage_port.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/authorized_terminal.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_identity.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_network.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:drift/drift.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

class DriftPosStorageAdapter implements PosStoragePort {
  DriftPosStorageAdapter({
    required SqliteDatabase database,
    required KeyValueStorageDatasource<String> secureStorage,
  }) : _database = database,
       _secureStorage = secureStorage;

  final SqliteDatabase _database;
  final KeyValueStorageDatasource<String> _secureStorage;

  @override
  Future<void> saveProfile(PosIdentity identity) {
    return _database
        .into(_database.posProfiles)
        .insertOnConflictUpdate(
          PosProfilesCompanion(
            merchantPubkey: Value(identity.ref.merchantPubkey),
            posId: Value(identity.ref.posId),
            walletId: Value(identity.walletId),
            masterFingerprint: Value(identity.masterFingerprint),
            recoveryPubkey: Value(identity.recoveryPubkey),
            relaysJson: Value(jsonEncode(identity.relays)),
            network: Value(identity.network.name),
            name: Value(identity.name),
            currency: Value(identity.currency),
            createdAt: Value(identity.createdAt.millisecondsSinceEpoch),
          ),
        );
  }

  @override
  Future<List<PosIdentity>> listProfiles() async {
    final rows = await (_database.select(
      _database.posProfiles,
    )..orderBy([(table) => OrderingTerm.desc(table.createdAt)])).get();
    return rows.map(_profileFromRow).toList();
  }

  @override
  Future<PosIdentity?> getLatestProfile() async {
    final profiles = await listProfiles();
    return profiles.isEmpty ? null : profiles.first;
  }

  @override
  Future<PosIdentity?> getProfile(PosRef ref) async {
    final query = _database.select(_database.posProfiles)
      ..where(
        (table) =>
            table.merchantPubkey.equals(ref.merchantPubkey) &
            table.posId.equals(ref.posId),
      );
    final row = await query.getSingleOrNull();
    return row == null ? null : _profileFromRow(row);
  }

  @override
  Future<int> nextTerminalIndex(PosRef ref) async {
    final terminals = await listAuthorizedTerminals(ref);
    if (terminals.isEmpty) return 0;
    return terminals
            .map((terminal) => terminal.terminalIndex)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  @override
  Future<void> saveAuthorizedTerminal({
    required AuthorizedTerminal terminal,
    required String ctDescriptor,
    required String saleBucketSecret,
  }) async {
    await _secureStorage.saveValue(
      key: terminal.ctDescriptorRef,
      value: ctDescriptor,
    );
    await _secureStorage.saveValue(
      key: terminal.saleBucketSecretRef,
      value: saleBucketSecret,
    );
    await _database
        .into(_database.posAuthorizedTerminals)
        .insertOnConflictUpdate(
          PosAuthorizedTerminalsCompanion(
            merchantPubkey: Value(terminal.posRef.merchantPubkey),
            posId: Value(terminal.posRef.posId),
            terminalPubkey: Value(terminal.terminalPubkey),
            terminalId: Value(terminal.terminalId),
            ctDescriptorRef: Value(terminal.ctDescriptorRef),
            saleBucketSecretRef: Value(terminal.saleBucketSecretRef),
            saleBucketGeneration: Value(terminal.saleBucketGeneration),
            effectiveFromEpochDay: Value(terminal.effectiveFromEpochDay),
            terminalIndex: Value(terminal.terminalIndex),
            authorizedAt: Value(terminal.authorizedAt.millisecondsSinceEpoch),
            revokedAt: Value(terminal.revokedAt?.millisecondsSinceEpoch),
          ),
        );
  }

  @override
  Future<List<AuthorizedTerminal>> listAuthorizedTerminals(PosRef ref) async {
    final query = _database.select(_database.posAuthorizedTerminals)
      ..where(
        (table) =>
            table.merchantPubkey.equals(ref.merchantPubkey) &
            table.posId.equals(ref.posId),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.terminalIndex)]);
    final rows = await query.get();
    return rows.map(_terminalFromRow).toList();
  }

  @override
  Future<String?> readTerminalDescriptor(AuthorizedTerminal terminal) {
    return _secureStorage.getValue(terminal.ctDescriptorRef);
  }

  @override
  Future<String?> readTerminalSaleBucketSecret(AuthorizedTerminal terminal) {
    return _secureStorage.getValue(terminal.saleBucketSecretRef);
  }

  @override
  Future<void> markTerminalRevoked({
    required PosRef ref,
    required String terminalPubkey,
    required DateTime revokedAt,
  }) async {
    await (_database.update(_database.posAuthorizedTerminals)..where(
          (table) =>
              table.merchantPubkey.equals(ref.merchantPubkey) &
              table.posId.equals(ref.posId) &
              table.terminalPubkey.equals(terminalPubkey),
        ))
        .write(
          PosAuthorizedTerminalsCompanion(
            revokedAt: Value(revokedAt.millisecondsSinceEpoch),
          ),
        );
  }

  @override
  Future<void> appendObservedEvents({
    required PosRef ref,
    required Iterable<nostr.NostrPosEvent> events,
  }) async {
    final eventList = events.toList();
    if (eventList.isEmpty) return;
    await _database.batch((batch) {
      batch.insertAllOnConflictUpdate(_database.posObservedEvents, [
        for (final event in eventList)
          PosObservedEventsCompanion(
            eventId: Value(event.id),
            kind: Value(event.kind),
            pubkey: Value(event.pubkey),
            createdAt: Value(event.createdAt),
            merchantPubkey: Value(ref.merchantPubkey),
            posId: Value(ref.posId),
            rawJson: Value(jsonEncode(event.toJson())),
          ),
      ]);
    });
  }

  @override
  Future<List<nostr.NostrPosEvent>> listObservedEvents(PosRef ref) async {
    final query = _database.select(_database.posObservedEvents)
      ..where(
        (table) =>
            table.merchantPubkey.equals(ref.merchantPubkey) &
            table.posId.equals(ref.posId),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
    final rows = await query.get();
    return rows
        .map((row) => nostr.NostrPosEvent.fromJson(_jsonMap(row.rawJson)))
        .toList();
  }

  PosIdentity _profileFromRow(PosProfileRow row) {
    final relays = (jsonDecode(row.relaysJson) as List).cast<String>();
    return PosIdentity(
      ref: PosRef(merchantPubkey: row.merchantPubkey, posId: row.posId),
      walletId: row.walletId,
      masterFingerprint: row.masterFingerprint,
      recoveryPubkey: row.recoveryPubkey,
      relays: relays,
      network: PosNetwork.fromName(row.network),
      name: row.name,
      currency: row.currency,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }

  AuthorizedTerminal _terminalFromRow(PosAuthorizedTerminalRow row) {
    return AuthorizedTerminal(
      posRef: PosRef(merchantPubkey: row.merchantPubkey, posId: row.posId),
      terminalPubkey: row.terminalPubkey,
      terminalId: row.terminalId,
      ctDescriptorRef: row.ctDescriptorRef,
      saleBucketSecretRef: row.saleBucketSecretRef,
      saleBucketGeneration: row.saleBucketGeneration,
      effectiveFromEpochDay: row.effectiveFromEpochDay,
      terminalIndex: row.terminalIndex,
      authorizedAt: DateTime.fromMillisecondsSinceEpoch(row.authorizedAt),
      revokedAt: row.revokedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.revokedAt!),
    );
  }

  Map<String, Object?> _jsonMap(String value) {
    return (jsonDecode(value) as Map).cast<String, Object?>();
  }
}
