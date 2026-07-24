import 'package:bb_mobile/core/wallet/data/datasources/wallet_birthday_checkpoint_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_birthday_checkpoint_response_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_birthday_checkpoint_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_genesis_block.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_birthday_checkpoint_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBirthdayCheckpointDatasource extends Mock
    implements WalletBirthdayCheckpointDatasource {}

void main() {
  late _MockWalletBirthdayCheckpointDatasource datasource;
  late WalletBirthdayCheckpointRepositoryImpl repository;

  setUp(() {
    datasource = _MockWalletBirthdayCheckpointDatasource();
    repository = WalletBirthdayCheckpointRepositoryImpl(datasource: datasource);
  });

  group('genesis shortcut', () {
    test(
      'a requested birthday at genesis resolves to it without any HTTP call',
      () async {
        final result = await repository.resolve(
          requestedBirthday: BitcoinGenesisBlock.mainnet.timestamp,
          isTestnet: false,
        );

        expect(
          result.fold((v) => v.blockHeight, (_) => -1),
          BitcoinGenesisBlock.mainnet.height,
        );
        expect(
          result.fold((v) => v.blockHash, (_) => ''),
          BitcoinGenesisBlock.mainnet.hash,
        );
        verifyNever(
          () => datasource.fetchBlockAtOrBeforeTimestamp(
            isTestnet: any(named: 'isTestnet'),
            unixSeconds: any(named: 'unixSeconds'),
          ),
        );
      },
    );

    test('a requested birthday before genesis also resolves locally', () async {
      final beforeGenesis = BitcoinGenesisBlock.mainnet.timestamp.subtract(
        const Duration(days: 1),
      );

      final result = await repository.resolve(
        requestedBirthday: beforeGenesis,
        isTestnet: false,
      );

      expect(result.fold((v) => v.blockHeight, (_) => -1), 0);
      verifyNever(
        () => datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: any(named: 'isTestnet'),
          unixSeconds: any(named: 'unixSeconds'),
        ),
      );
    });

    test('picks the testnet genesis when isTestnet is true', () async {
      final result = await repository.resolve(
        requestedBirthday: BitcoinGenesisBlock.testnet.timestamp,
        isTestnet: true,
      );

      expect(
        result.fold((v) => v.blockHash, (_) => ''),
        BitcoinGenesisBlock.testnet.hash,
      );
    });
  });

  group('HTTP lookup', () {
    final requested = DateTime.utc(2026, 3, 10, 12);

    test('a well-formed, on-time response resolves successfully', () async {
      when(
        () => datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: false,
          unixSeconds: requested.millisecondsSinceEpoch ~/ 1000,
        ),
      ).thenAnswer(
        (_) async => WalletBirthdayCheckpointResponseModel(
          height: 900000,
          hash: 'a' * 64,
          timestamp: requested.subtract(const Duration(minutes: 5)),
        ),
      );

      final result = await repository.resolve(
        requestedBirthday: requested,
        isTestnet: false,
      );

      expect(result.fold((v) => v.blockHeight, (_) => -1), 900000);
      expect(result.fold((v) => v.blockHash, (_) => ''), 'a' * 64);
    });

    test('retries at an earlier instant when the server answers later than '
        'requested, and succeeds once it answers correctly', () async {
      var call = 0;
      when(
        () => datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: false,
          unixSeconds: any(named: 'unixSeconds'),
        ),
      ).thenAnswer((_) async {
        call++;
        if (call == 1) {
          return WalletBirthdayCheckpointResponseModel(
            height: 900001,
            hash: 'b' * 64,
            timestamp: requested.add(const Duration(hours: 1)),
          );
        }
        return WalletBirthdayCheckpointResponseModel(
          height: 900000,
          hash: 'a' * 64,
          timestamp: requested.subtract(const Duration(minutes: 5)),
        );
      });

      final result = await repository.resolve(
        requestedBirthday: requested,
        isTestnet: false,
      );

      expect(result.fold((v) => v.blockHeight, (_) => -1), 900000);
      verify(
        () => datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: false,
          unixSeconds: any(named: 'unixSeconds'),
        ),
      ).called(2);
    });

    test('fails with a typed lookup failure once retries are exhausted against '
        'a persistently misbehaving server', () async {
      when(
        () => datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: false,
          unixSeconds: any(named: 'unixSeconds'),
        ),
      ).thenAnswer(
        (_) async => WalletBirthdayCheckpointResponseModel(
          height: 900001,
          hash: 'b' * 64,
          timestamp: requested.add(const Duration(hours: 1)),
        ),
      );

      final result = await repository.resolve(
        requestedBirthday: requested,
        isTestnet: false,
      );

      expect(
        result.fold((_) => null, (f) => f),
        isA<WalletBirthdayCheckpointLookupFailure>(),
      );
      verify(
        () => datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: false,
          unixSeconds: any(named: 'unixSeconds'),
        ),
      ).called(3);
    });

    test('maps a datasource exception (network/parse failure) to a typed '
        'lookup failure', () async {
      when(
        () => datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: false,
          unixSeconds: any(named: 'unixSeconds'),
        ),
      ).thenThrow(Exception('no active mempool server'));

      final result = await repository.resolve(
        requestedBirthday: requested,
        isTestnet: false,
      );

      expect(
        result.fold((_) => null, (f) => f),
        isA<WalletBirthdayCheckpointLookupFailure>(),
      );
      verify(
        () => datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: false,
          unixSeconds: any(named: 'unixSeconds'),
        ),
      ).called(1);
    });

    test('maps an invalid block shape in the response (bad hash) to a typed '
        'lookup failure without retrying', () async {
      when(
        () => datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: false,
          unixSeconds: any(named: 'unixSeconds'),
        ),
      ).thenAnswer(
        (_) async => WalletBirthdayCheckpointResponseModel(
          height: 900000,
          hash: 'not-a-valid-hash',
          timestamp: requested.subtract(const Duration(minutes: 5)),
        ),
      );

      final result = await repository.resolve(
        requestedBirthday: requested,
        isTestnet: false,
      );

      expect(
        result.fold((_) => null, (f) => f),
        isA<WalletBirthdayCheckpointLookupFailure>(),
      );
      verify(
        () => datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: false,
          unixSeconds: any(named: 'unixSeconds'),
        ),
      ).called(1);
    });
  });
}
