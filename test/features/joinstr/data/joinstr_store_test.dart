import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryStorage implements KeyValueStorageDatasource<String> {
  final Map<String, String> values = {};

  @override
  Future<void> saveValue({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<Map<String, String>> getAll() async => Map.of(values);

  @override
  Future<String?> getValue(String key) async => values[key];

  @override
  Future<bool> hasValue(String key) async => values.containsKey(key);

  @override
  Future<void> deleteValue(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

JoinstrHistoryEntry _entry(String txId) => JoinstrHistoryEntry(
  amountSat: 100000,
  txId: txId,
  relay: 'wss://nos.lol',
  completedAtUnixSec: 1793500000,
);

void main() {
  late _InMemoryStorage storage;
  late JoinstrStore store;

  setUp(() {
    storage = _InMemoryStorage();
    store = JoinstrStore(storage);
  });

  group('relay', () {
    test('returns null before anything is saved', () async {
      expect(await store.getRelay(), isNull);
    });

    test('round-trips and trims the saved relay', () async {
      await store.saveRelay(' wss://relay.example ');
      expect(await store.getRelay(), 'wss://relay.example');
    });
  });

  group('history', () {
    test('is empty before anything is saved', () async {
      expect(await store.getHistory(), isEmpty);
    });

    test('appends newest first and round-trips through json', () async {
      await store.appendHistory(_entry('tx-1'));
      await store.appendHistory(_entry('tx-2'));

      final history = await store.getHistory();
      expect(history.map((e) => e.txId), ['tx-2', 'tx-1']);
      expect(history.first.amountSat, 100000);
      expect(history.first.relay, 'wss://nos.lol');
      expect(history.first.completedAtUnixSec, 1793500000);
    });

    test('survives corrupt stored json rather than throwing', () async {
      storage.values[JoinstrStore.historyKey] = 'not json';
      expect(await store.getHistory(), isEmpty);

      storage.values[JoinstrStore.historyKey] = '{"a":1}';
      expect(await store.getHistory(), isEmpty);
    });

    test('drops undecodable entries without losing the rest', () async {
      storage.values[JoinstrStore.historyKey] =
          '[{"amountSat":"wrong type"},'
          '{"amountSat":1,"txId":"tx-ok","relay":"wss://nos.lol",'
          '"completedAtUnixSec":2}]';

      final history = await store.getHistory();
      expect(history.single.txId, 'tx-ok');
    });

    test('a corrupt store is overwritten by the next append', () async {
      storage.values[JoinstrStore.historyKey] = 'not json';
      await store.appendHistory(_entry('tx-1'));
      expect((await store.getHistory()).single.txId, 'tx-1');
    });

    test('concurrent appends from parallel rounds keep every entry', () async {
      await Future.wait([
        store.appendHistory(_entry('tx-1')),
        store.appendHistory(_entry('tx-2')),
        store.appendHistory(_entry('tx-3')),
      ]);

      final history = await store.getHistory();
      expect(history.map((e) => e.txId).toSet(), {'tx-1', 'tx-2', 'tx-3'});
    });
  });
}
