import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/record_unconfirmed_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBitcoinBlockchainRepository extends Mock
    implements BitcoinBlockchainRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockRecordUnconfirmedBitcoinTransactionUsecase extends Mock
    implements RecordUnconfirmedBitcoinTransactionUsecase {}

const _settings = SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
);

void main() {
  late _MockBitcoinBlockchainRepository bitcoinBlockchain;
  late _MockSettingsRepository settingsRepository;
  late _MockRecordUnconfirmedBitcoinTransactionUsecase recordUsecase;
  late BroadcastBitcoinTransactionUsecase usecase;

  void verifyNoRecordCall() {
    verifyNever(
      () => recordUsecase.execute(
        walletId: any(named: 'walletId'),
        transaction: any(named: 'transaction'),
        isPsbt: any(named: 'isPsbt'),
      ),
    );
  }

  setUp(() {
    bitcoinBlockchain = _MockBitcoinBlockchainRepository();
    settingsRepository = _MockSettingsRepository();
    recordUsecase = _MockRecordUnconfirmedBitcoinTransactionUsecase();
    usecase = BroadcastBitcoinTransactionUsecase(
      bitcoinBlockchainRepository: bitcoinBlockchain,
      settingsRepository: settingsRepository,
      recordUnconfirmedBitcoinTransactionUsecase: recordUsecase,
    );

    when(() => settingsRepository.fetch()).thenAnswer((_) async => _settings);
  });

  group('execute — no walletId', () {
    test('returns the txid and never calls the record usecase', () async {
      when(
        () => bitcoinBlockchain.broadcastPsbt(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => 'txid-1');

      final txId = await usecase.execute('psbt', isPsbt: true);

      expect(txId, 'txid-1');
      verifyNoRecordCall();
    });
  });

  group('execute — with walletId', () {
    test('records the transaction after a successful broadcast, with the '
        'exact transaction/isPsbt/walletId that were broadcast', () async {
      when(
        () => bitcoinBlockchain.broadcastPsbt(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => 'txid-2');
      when(
        () => recordUsecase.execute(
          walletId: any(named: 'walletId'),
          transaction: any(named: 'transaction'),
          isPsbt: any(named: 'isPsbt'),
        ),
      ).thenAnswer((_) async => const Ok(null));

      final txId = await usecase.execute(
        'signed-psbt',
        isPsbt: true,
        walletId: 'wallet-1',
      );

      expect(txId, 'txid-2');
      verify(
        () => recordUsecase.execute(
          walletId: 'wallet-1',
          transaction: 'signed-psbt',
          isPsbt: true,
        ),
      ).called(1);
    });

    test('a local recording Err never masks the already-successful broadcast '
        '— the txid is still returned', () async {
      when(
        () => bitcoinBlockchain.broadcastPsbt(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => 'txid-3');
      when(
        () => recordUsecase.execute(
          walletId: any(named: 'walletId'),
          transaction: any(named: 'transaction'),
          isPsbt: any(named: 'isPsbt'),
        ),
      ).thenAnswer((_) async => const Err(WalletSyncCbfFailure('boom')));

      final txId = await usecase.execute(
        'signed-psbt',
        isPsbt: true,
        walletId: 'wallet-1',
      );

      expect(txId, 'txid-3');
    });

    test('a thrown exception from the record usecase never masks the '
        'already-successful broadcast — the txid is still returned', () async {
      when(
        () => bitcoinBlockchain.broadcastPsbt(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => 'txid-4');
      when(
        () => recordUsecase.execute(
          walletId: any(named: 'walletId'),
          transaction: any(named: 'transaction'),
          isPsbt: any(named: 'isPsbt'),
        ),
      ).thenThrow(Exception('unexpected'));

      final txId = await usecase.execute(
        'signed-psbt',
        isPsbt: true,
        walletId: 'wallet-1',
      );

      expect(txId, 'txid-4');
    });

    test(
      'a broadcast failure is never masked, and never triggers recording',
      () async {
        when(
          () => bitcoinBlockchain.broadcastPsbt(
            any(),
            isTestnet: any(named: 'isTestnet'),
          ),
        ).thenThrow(Exception('network down'));

        await expectLater(
          usecase.execute('signed-psbt', isPsbt: true, walletId: 'wallet-1'),
          throwsA(isA<BroadcastTransactionException>()),
        );

        verifyNoRecordCall();
      },
    );

    test('a raw (non-PSBT) transaction is broadcast and recorded with the '
        'exact same raw hex string', () async {
      when(
        () => bitcoinBlockchain.broadcastTransaction(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => 'txid-5');
      when(
        () => recordUsecase.execute(
          walletId: any(named: 'walletId'),
          transaction: any(named: 'transaction'),
          isPsbt: any(named: 'isPsbt'),
        ),
      ).thenAnswer((_) async => const Ok(null));

      final txId = await usecase.execute(
        'deadbeef',
        isPsbt: false,
        walletId: 'wallet-1',
      );

      expect(txId, 'txid-5');
      verify(
        () => recordUsecase.execute(
          walletId: 'wallet-1',
          transaction: 'deadbeef',
          isPsbt: false,
        ),
      ).called(1);
    });
  });
}
