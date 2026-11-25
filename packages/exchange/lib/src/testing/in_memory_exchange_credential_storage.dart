import '../data/storage/exchange_credential_storage.dart';
import '../domain/exchange_basic_auth.dart';

/// Scenario storage for tests. Override a method to delay or refuse it.
class InMemoryExchangeCredentialStorage implements ExchangeCredentialStorage {
  /// Stored records by environment name, `mainnet` or `testnet`.
  final entries = <String, String>{};

  /// Outcomes served by [readApiKeyRecord], in order, before [entries]: a
  /// `String?` is returned as is and an [Exception] is thrown.
  final scripted = <Object?>[];

  /// Outcomes raised by [writeApiKeyRecord], in order. One entry is consumed
  /// per call; a non-exception entry lets the call succeed.
  final scriptedWrites = <Object?>[];

  /// The environment of every read, in order.
  final readKeys = <String>[];
  String? username;
  String? password;
  bool closed = false;

  @override
  Future<String?> readApiKeyRecord({required bool isTestnet}) async {
    final key = _name(isTestnet);
    readKeys.add(key);
    if (scripted.isNotEmpty) {
      final next = scripted.removeAt(0);
      if (next is Exception) throw next;
      return next as String?;
    }
    return entries[key];
  }

  @override
  Future<void> writeApiKeyRecord(
    String? record, {
    required bool isTestnet,
  }) async {
    if (scriptedWrites.isNotEmpty) {
      final next = scriptedWrites.removeAt(0);
      if (next is Exception) throw next;
    }
    final key = _name(isTestnet);
    if (record == null) {
      entries.remove(key);
    } else {
      entries[key] = record;
    }
  }

  @override
  Future<ExchangeBasicAuthValues> readBasicAuth() async =>
      (username: username, password: password);

  @override
  Future<void> writeBasicAuth({String? username, String? password}) async {
    this.username = username;
    this.password = password;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  static String _name(bool isTestnet) => isTestnet ? 'testnet' : 'mainnet';
}
