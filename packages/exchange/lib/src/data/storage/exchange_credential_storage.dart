import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show DatabaseKeys;

import '../../domain/exchange_basic_auth.dart';
import '../../domain/exchange_failure.dart';
import 'exchange_database.dart';
import 'exchange_readiness.dart';
import 'exchange_store.dart';

/// Runtime access to the encrypted Exchange store. It exists only after the
/// cutover admitted the owner; it is never created or repaired here, so a
/// missing or unreadable store fails closed instead of starting a new session.
/// Every method throws an [Exception] on a storage error.
abstract interface class ExchangeCredentialStorage {
  /// Opens an admitted store. [admission] keeps the native handle tracked
  /// until [close]; the lifecycle gate frees the family for a later migration
  /// only after that handle is confirmed closed.
  static Future<Result<ExchangeCredentialStorage, ExchangeFailure>> open({
    required File file,
    required RuntimeAdmission admission,
  }) async => _admit(
    await ExchangeStore.open(file: file, admission: admission, existing: true),
  );

  /// Uses the fake keystore of the test isolate.
  static Future<Result<ExchangeCredentialStorage, ExchangeFailure>>
  openForTesting({
    required File file,
    required RuntimeAdmission admission,
    required DatabaseKeys keys,
  }) async => _admit(
    await ExchangeStore.openForTesting(
      file: file,
      admission: admission,
      keys: keys,
      existing: true,
    ),
  );

  /// The stored record exactly as written, or null when none is stored.
  Future<String?> readApiKeyRecord({required bool isTestnet});

  /// Replaces the record, or removes it when [record] is null.
  Future<void> writeApiKeyRecord(String? record, {required bool isTestnet});

  Future<ExchangeBasicAuthValues> readBasicAuth();

  Future<void> writeBasicAuth({String? username, String? password});

  /// Confirms the native close or throws, leaving the admission to retain it.
  Future<void> close();
}

Future<Result<ExchangeCredentialStorage, ExchangeFailure>> _admit(
  Result<ExchangeStore, LegacyImportFailure> opened,
) async {
  if (opened case Err()) {
    return const Err(ExchangeCredentialsUnavailableFailure());
  }
  final store = (opened as Ok<ExchangeStore, LegacyImportFailure>).value;
  final readiness = await readExchangeReadiness(store.database);
  final ready =
      readiness is Ok<OwnerReadiness, LegacyImportFailure> &&
      readiness.value != OwnerReadiness.pending;
  if (!ready) {
    try {
      await store.handle.close();
    } on Exception {
      // The admission still owns the unconfirmed native handle.
    }
    return const Err(ExchangeCredentialsUnavailableFailure());
  }
  return Ok(_StoredCredentialStorage(store));
}

final class _StoredCredentialStorage implements ExchangeCredentialStorage {
  static const _settingsRow = 1;
  final ExchangeStore _store;

  const _StoredCredentialStorage(this._store);

  ExchangeDatabase get _db => _store.database;

  @override
  Future<String?> readApiKeyRecord({required bool isTestnet}) async {
    final row = await _db
        .customSelect(
          'SELECT encoded_record FROM exchange_api_credentials '
          'WHERE environment = ?',
          variables: [Variable<String>(_environment(isTestnet))],
        )
        .getSingleOrNull();
    if (row == null) throw const ExchangeStoreInvariantException();
    return row.readNullable<String>('encoded_record');
  }

  @override
  Future<void> writeApiKeyRecord(
    String? record, {
    required bool isTestnet,
  }) async {
    final changed = await _db.customUpdate(
      'UPDATE exchange_api_credentials SET encoded_record = ? '
      'WHERE environment = ?',
      variables: [
        Variable<String>(record),
        Variable<String>(_environment(isTestnet)),
      ],
    );
    if (changed != 1) throw const ExchangeStoreInvariantException();
  }

  @override
  Future<ExchangeBasicAuthValues> readBasicAuth() async {
    final row = await _db
        .customSelect(
          'SELECT username, password FROM exchange_basic_auth '
          'WHERE settings_id = ?',
          variables: [const Variable<int>(_settingsRow)],
        )
        .getSingleOrNull();
    if (row == null) throw const ExchangeStoreInvariantException();
    return (
      username: row.readNullable<String>('username'),
      password: row.readNullable<String>('password'),
    );
  }

  @override
  Future<void> writeBasicAuth({String? username, String? password}) async {
    final changed = await _db.customUpdate(
      'UPDATE exchange_basic_auth SET username = ?, password = ? '
      'WHERE settings_id = ?',
      variables: [
        Variable<String>(username),
        Variable<String>(password),
        const Variable<int>(_settingsRow),
      ],
    );
    if (changed != 1) throw const ExchangeStoreInvariantException();
  }

  @override
  Future<void> close() => _store.handle.close();

  static String _environment(bool isTestnet) =>
      isTestnet ? 'testnet' : 'mainnet';
}

/// The store lacks a row that admission guarantees.
final class ExchangeStoreInvariantException implements Exception {
  const ExchangeStoreInvariantException();
}
