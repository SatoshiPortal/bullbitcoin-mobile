import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/transactions/data/datasources/send_timestamp_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBitcoin extends Mock implements BitcoinBlockchainRepository {}

class _MockLiquid extends Mock implements LiquidBlockchainRepository {}

class _MockSettings extends Mock implements SettingsRepository {}

class _MockSendTimestamps extends Mock implements SendTimestampDatasource {}

const _txid =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  late _MockSettings settings;
  late _MockSendTimestamps timestamps;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    settings = _MockSettings();
    timestamps = _MockSendTimestamps();
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => timestamps.record(
        txid: any(named: 'txid'),
        sentAt: any(named: 'sentAt'),
      ),
    ).thenAnswer((_) async {});
  });

  group('bitcoin', () {
    test('records the broadcast moment against the returned txid', () async {
      final chain = _MockBitcoin();
      when(
        () => chain.broadcastTransaction(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => _txid);

      final usecase = BroadcastBitcoinTransactionUsecase(
        bitcoinBlockchainRepository: chain,
        settingsRepository: settings,
        sendTimestampDatasource: timestamps,
      );

      final result = await usecase.execute('00', isPsbt: false);

      expect(result, _txid);
      verify(
        () => timestamps.record(
          txid: _txid,
          sentAt: any(named: 'sentAt'),
        ),
      ).called(1);
    });

    test('a failed recording never fails the send', () async {
      // The money has already moved. Losing the row only costs the send its
      // exact anchor; it falls back to confirmation time like any receive.
      final chain = _MockBitcoin();
      when(
        () => chain.broadcastTransaction(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => _txid);
      when(
        () => timestamps.record(
          txid: any(named: 'txid'),
          sentAt: any(named: 'sentAt'),
        ),
      ).thenThrow(Exception('disk full'));

      final usecase = BroadcastBitcoinTransactionUsecase(
        bitcoinBlockchainRepository: chain,
        settingsRepository: settings,
        sendTimestampDatasource: timestamps,
      );

      await expectLater(
        usecase.execute('00', isPsbt: false),
        completion(_txid),
      );
    });

    test('records nothing when the broadcast itself fails', () async {
      final chain = _MockBitcoin();
      when(
        () => chain.broadcastTransaction(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenThrow(Exception('no peers'));

      final usecase = BroadcastBitcoinTransactionUsecase(
        bitcoinBlockchainRepository: chain,
        settingsRepository: settings,
        sendTimestampDatasource: timestamps,
      );

      await expectLater(
        usecase.execute('00', isPsbt: false),
        throwsA(isA<Exception>()),
      );
      verifyNever(
        () => timestamps.record(
          txid: any(named: 'txid'),
          sentAt: any(named: 'sentAt'),
        ),
      );
    });
  });

  group('liquid', () {
    test('records the broadcast moment against the returned txid', () async {
      final chain = _MockLiquid();
      when(
        () => chain.broadcastTransaction(
          signedPset: any(named: 'signedPset'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => _txid);

      final usecase = BroadcastLiquidTransactionUsecase(
        liquidBlockchainRepository: chain,
        settingsRepository: settings,
        sendTimestampDatasource: timestamps,
      );

      final result = await usecase.execute('pset');

      expect(result, _txid);
      verify(
        () => timestamps.record(
          txid: _txid,
          sentAt: any(named: 'sentAt'),
        ),
      ).called(1);
    });
  });
}
