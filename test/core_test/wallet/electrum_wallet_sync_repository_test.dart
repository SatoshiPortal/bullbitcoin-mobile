import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/electrum_wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _FakeWallet extends Fake implements Wallet {
  _FakeWallet(this.id);

  @override
  final String id;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeWallet('fallback'));
  });

  late _MockWalletRepository walletRepository;
  late ElectrumWalletSyncRepository repository;

  setUp(() {
    walletRepository = _MockWalletRepository();
    repository = ElectrumWalletSyncRepository(
      walletRepository: walletRepository,
    );
  });

  group('ElectrumWalletSyncRepository.startSync', () {
    const walletId = 'wallet-1';

    test('wallet not found -> WalletSyncWalletNotFoundFailure', () async {
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => null);

      final result = await repository.startSync(walletId: walletId);

      expect(result, isA<Err<void, WalletSyncFailure>>());
      final failure = (result as Err<void, WalletSyncFailure>).failure;
      expect(failure, isA<WalletSyncWalletNotFoundFailure>());
      verifyNever(() => walletRepository.sync(any()));
    });

    test('delegates the actual sync call to WalletRepository.sync unchanged '
        'and reports Ok on success', () async {
      final wallet = _FakeWallet(walletId);
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => wallet);
      when(() => walletRepository.sync(wallet)).thenAnswer((_) async {});

      final progressEvents = <WalletSyncProgress>[];
      final subscription = repository.watchProgress().listen(
        progressEvents.add,
      );

      final result = await repository.startSync(walletId: walletId);
      // Broadcast-stream events are delivered on a later microtask; flush
      // the queue before asserting on everything the listener collected.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(result, isA<Ok<void, WalletSyncFailure>>());
      verify(() => walletRepository.sync(wallet)).called(1);
      expect(progressEvents, [
        isA<WalletSyncStarted>()
            .having((e) => e.walletId, 'walletId', walletId)
            .having((e) => e.backend, 'backend', BitcoinSyncBackend.electrum),
        isA<WalletSyncCompleted>().having(
          (e) => e.walletId,
          'walletId',
          walletId,
        ),
      ]);
    });

    test('every Electrum server failing -> WalletSyncElectrumFailure, '
        'no progress completion event', () async {
      final wallet = _FakeWallet(walletId);
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => wallet);
      when(() => walletRepository.sync(wallet)).thenThrow(
        NoElectrumServersConfiguredException(
          ElectrumServerNetwork.bitcoinMainnet,
        ),
      );

      final progressEvents = <WalletSyncProgress>[];
      final subscription = repository.watchProgress().listen(
        progressEvents.add,
      );

      final result = await repository.startSync(walletId: walletId);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(result, isA<Err<void, WalletSyncFailure>>());
      expect(
        (result as Err<void, WalletSyncFailure>).failure,
        isA<WalletSyncElectrumFailure>(),
      );
      expect(progressEvents, [
        isA<WalletSyncStarted>(),
        isA<WalletSyncFailed>().having(
          (e) => e.category,
          'category',
          WalletSyncFailureCategory.electrum,
        ),
      ]);
    });

    test('an unmodeled error -> WalletSyncUnexpectedFailure', () async {
      final wallet = _FakeWallet(walletId);
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => wallet);
      when(() => walletRepository.sync(wallet)).thenThrow(Exception('boom'));

      final result = await repository.startSync(walletId: walletId);

      expect(
        (result as Err<void, WalletSyncFailure>).failure,
        isA<WalletSyncUnexpectedFailure>(),
      );
    });
  });

  test('cancelSync is a documented no-op for the Electrum backend', () async {
    await expectLater(repository.cancelSync(walletId: 'wallet-1'), completes);
  });
}
