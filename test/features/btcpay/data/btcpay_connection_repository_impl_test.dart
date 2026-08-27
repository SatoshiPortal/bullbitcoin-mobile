import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/data/btcpay_connection_repository_impl.dart';
import 'package:bb_mobile/features/btcpay/data/datasources/btcpay_connection_datasource.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BtcpayConnectionRepositoryImpl repositoryWith(_MemoryStorage storage) {
    return BtcpayConnectionRepositoryImpl(
      BtcpayConnectionDatasource(storage: storage),
    );
  }

  test('stores connections under the active environment only', () async {
    final storage = _MemoryStorage();
    final repository = repositoryWith(storage);
    final connection = _connection();

    expect(
      await repository.saveConnection(connection),
      isA<Ok<void, BtcpayFailure>>(),
    );

    final mainnet = _okValue(
      await repository.getConnection(Environment.mainnet),
    );
    final testnet = _okValue(
      await repository.getConnection(Environment.testnet),
    );
    expect(mainnet, isNotNull);
    expect(mainnet!.environment, Environment.mainnet);
    expect(mainnet.storeId, 'store123');
    expect(mainnet.isUncertain, isTrue);
    expect(mainnet.supportsLightning, isTrue);
    expect(mainnet.lastError, 'safe local status');
    expect(testnet, isNull);
  });

  test('returns Ok(null) only when no connection is stored', () async {
    final repository = repositoryWith(_MemoryStorage());

    expect(
      _okValue(await repository.getConnection(Environment.mainnet)),
      isNull,
    );
  });

  test('classifies malformed stored JSON as a storage failure', () async {
    final storage = _MemoryStorage(
      values: {'btcpay_connection_mainnet': 'not-json'},
    );
    final repository = repositoryWith(storage);

    expect(
      _errValue(await repository.getConnection(Environment.mainnet)),
      isA<BtcpayStorageFailure>(),
    );
  });

  test('classifies semantically invalid records as storage failures', () async {
    final storage = _MemoryStorage(
      values: {
        'btcpay_connection_mainnet':
            '{"environment":"mainnet","serverUrl":"https://btcpay.example.com",'
            '"storeId":"store123","status":"paired","capabilities":["btc-chain"],'
            '"walletNetworks":["bitcoin"],"pairedAt":null,'
            '"updatedAt":"2026-05-23T00:00:00.000Z"}',
      },
    );
    final repository = repositoryWith(storage);

    expect(
      _errValue(await repository.getConnection(Environment.mainnet)),
      isA<BtcpayStorageFailure>(),
    );
  });

  test('rejects malformed or unknown stored list values', () async {
    const prefix =
        '{"environment":"mainnet","serverUrl":"https://btcpay.example.com",'
        '"storeId":"store123","status":"uncertain",';
    const suffix =
        '"walletNetworks":["bitcoin"],"pairedAt":null,'
        '"updatedAt":"2026-05-23T00:00:00.000Z"}';
    for (final capabilities in <String>[
      '["btc-chain",7],',
      '["unknown-capability"],',
    ]) {
      final storage = _MemoryStorage(
        values: {
          'btcpay_connection_mainnet':
              '$prefix"capabilities":$capabilities$suffix',
        },
      );

      expect(
        _errValue(
          await repositoryWith(storage).getConnection(Environment.mainnet),
        ),
        isA<BtcpayStorageFailure>(),
      );
    }
  });

  test('maps storage read and write exceptions to typed failures', () async {
    final readRepository = repositoryWith(_MemoryStorage(throwOnRead: true));
    final writeRepository = repositoryWith(_MemoryStorage(throwOnWrite: true));

    expect(
      _errValue(await readRepository.getConnection(Environment.mainnet)),
      isA<BtcpayStorageFailure>(),
    );
    expect(
      _errValue(await writeRepository.saveConnection(_connection())),
      isA<BtcpayStorageFailure>(),
    );
  });
}

BtcpayConnection _connection() {
  return BtcpayConnection.tryCreate(
    environment: Environment.mainnet,
    serverUrl: 'https://btcpay.example.com',
    storeId: 'store123',
    capabilities: const [
      SamRockSetupCapability.bitcoinChain,
      SamRockSetupCapability.liquidChain,
      SamRockSetupCapability.bitcoinLightning,
    ],
    walletNetworks: const [
      BtcpayWalletNetwork.bitcoin,
      BtcpayWalletNetwork.liquid,
    ],
    status: BtcpayConnectionStatus.uncertain,
    pairedAt: null,
    updatedAt: DateTime.utc(2026, 5, 23),
    lastError: 'safe local status',
  )!;
}

T _okValue<T>(Result<T, BtcpayFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure(
    'Expected Ok, got ${failure.runtimeType}',
  ),
};

BtcpayFailure _errValue<T>(Result<T, BtcpayFailure> result) => switch (result) {
  Ok() => throw TestFailure('Expected Err, got Ok'),
  Err(:final failure) => failure,
};

class _MemoryStorage implements KeyValueStorageDatasource<String> {
  final Map<String, String> _values;
  final bool throwOnRead;
  final bool throwOnWrite;

  _MemoryStorage({
    Map<String, String> values = const {},
    this.throwOnRead = false,
    this.throwOnWrite = false,
  }) : _values = Map.of(values);

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);

  @override
  Future<Map<String, String>> getAll() async => Map.of(_values);

  @override
  Future<String?> getValue(String key) async {
    if (throwOnRead) throw Exception('read failed');
    return _values[key];
  }

  @override
  Future<bool> hasValue(String key) async => _values.containsKey(key);

  @override
  Future<void> saveValue({required String key, required String value}) async {
    if (throwOnWrite) throw Exception('write failed');
    _values[key] = value;
  }
}
