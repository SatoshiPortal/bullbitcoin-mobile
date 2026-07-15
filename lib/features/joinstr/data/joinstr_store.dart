import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';

/// Persists the joinstr relay preference and coinjoin history. Backed by the
/// app's secure key-value storage: which coins were mixed and when is exactly
/// the linkage a coinjoin exists to hide, so it never lands in plain storage.
class JoinstrStore {
  static const relayKey = 'joinstr_relay';
  static const historyKey = 'joinstr_history';
  static const reservedAddressKey = 'joinstr_reserved_address';

  final KeyValueStorageDatasource<String> _storage;

  const JoinstrStore(this._storage);

  Future<String?> getRelay() => _storage.getValue(relayKey);

  Future<void> saveRelay(String relay) =>
      _storage.saveValue(key: relayKey, value: relay.trim());

  /// The receive address reserved for the current round. It is reused across
  /// retries so repeated failed attempts do not walk the receive chain toward
  /// the gap limit, and cleared on a successful broadcast so the next round
  /// gets a fresh address rather than reusing a now-funded one on-chain.
  Future<String?> getReservedAddress() => _storage.getValue(reservedAddressKey);

  Future<void> saveReservedAddress(String address) =>
      _storage.saveValue(key: reservedAddressKey, value: address);

  Future<void> clearReservedAddress() =>
      _storage.deleteValue(reservedAddressKey);

  Future<List<JoinstrHistoryEntry>> getHistory() async {
    final raw = await _storage.getValue(historyKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(JoinstrHistoryEntry.fromJson)
          .whereType<JoinstrHistoryEntry>()
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> appendHistory(JoinstrHistoryEntry entry) async {
    final history = await getHistory();
    final updated = [entry, ...history];
    await _storage.saveValue(
      key: historyKey,
      value: jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }
}
