import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/cancel_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_sync_progress_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake standing in for a real `WalletSyncRepository`
/// implementation (Electrum or, later, compact-filter). These usecases are
/// pure delegation, so the fake only needs to record calls and let the test
/// script the return value.
class _FakeWalletSyncRepository implements WalletSyncRepository {
  String? startedWalletId;
  String? cancelledWalletId;
  Result<void, WalletSyncFailure> startSyncResult = const Ok(null);
  final _progressController = StreamController<WalletSyncProgress>.broadcast();

  @override
  Future<Result<void, WalletSyncFailure>> startSync({
    required String walletId,
  }) async {
    startedWalletId = walletId;
    return startSyncResult;
  }

  @override
  Stream<WalletSyncProgress> watchProgress() => _progressController.stream;

  @override
  Future<void> cancelSync({required String walletId}) async {
    cancelledWalletId = walletId;
  }

  void dispose() => _progressController.close();
}

void main() {
  late _FakeWalletSyncRepository fakeRepository;

  setUp(() {
    fakeRepository = _FakeWalletSyncRepository();
  });

  tearDown(() {
    fakeRepository.dispose();
  });

  test(
    'StartWalletSyncUsecase forwards the walletId and result unchanged',
    () async {
      fakeRepository.startSyncResult = const Err(
        WalletSyncElectrumFailure('no servers'),
      );
      final usecase = StartWalletSyncUsecase(
        walletSyncRepository: fakeRepository,
      );

      final result = await usecase.execute(walletId: 'wallet-1');

      expect(fakeRepository.startedWalletId, 'wallet-1');
      expect(result, same(fakeRepository.startSyncResult));
    },
  );

  test(
    'WatchWalletSyncProgressUsecase forwards the repository stream',
    () async {
      final usecase = WatchWalletSyncProgressUsecase(
        walletSyncRepository: fakeRepository,
      );

      final events = <WalletSyncProgress>[];
      final subscription = usecase.execute().listen(events.add);
      fakeRepository._progressController.add(
        const WalletSyncStarted('w1', BitcoinSyncBackend.electrum),
      );
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(events, [isA<WalletSyncStarted>()]);
    },
  );

  test('CancelWalletSyncUsecase forwards the walletId', () async {
    final usecase = CancelWalletSyncUsecase(
      walletSyncRepository: fakeRepository,
    );

    await usecase.execute(walletId: 'wallet-2');

    expect(fakeRepository.cancelledWalletId, 'wallet-2');
  });
}
