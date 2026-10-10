import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_auto_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_scan_policy.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';

class _MockGetSpWalletUsecase extends Mock implements GetSpWalletUsecase {}

void main() {
  const tip = 900000;

  late FakeSpAccountRepository repo;
  late _MockGetSpWalletUsecase getWallet;
  late SyncSpWalletUsecase usecase;
  late FakeSpAutoScanRepository autoScanRepo;

  SyncSpWalletUsecase build() => SyncSpWalletUsecase(
    repository: repo,
    getSpWalletUsecase: getWallet,
    isSpScanningUsecase: IsSpScanningUsecase(repository: repo),
    scanSpWalletUsecase: ScanSpWalletUsecase(repository: repo),
    getSpAutoScanUsecase: GetSpAutoScanUsecase(repository: autoScanRepo),
  );

  void walletAt(int? lastScannedHeight) {
    when(() => getWallet.execute()).thenAnswer(
      (_) async => Ok(spWallet(lastScannedHeight: lastScannedHeight)),
    );
  }

  setUp(() {
    repo = FakeSpAccountRepository();
    repo.chainTipValue = tip;
    getWallet = _MockGetSpWalletUsecase();
    autoScanRepo = FakeSpAutoScanRepository();
    // Default: a wallet a few blocks behind, i.e. one a tick would scan.
    walletAt(tip - 10);
    usecase = build();
  });

  group('SyncSpWalletUsecase resumes the scan', () {
    test('scans when the cursor is close enough to the tip', () async {
      walletAt(tip - 10);

      final result = await usecase.execute();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(repo.scanOnceCount, 1);
      expect(
        repo.lastScanStartHeight,
        isNull,
        reason: 'a resume scan continues from the stored cursor',
      );
    });

    test('scans at exactly the threshold', () async {
      walletAt(tip - spAutoScanMaxBlocksBehind);

      await usecase.execute();

      expect(repo.scanOnceCount, 1);
    });
  });

  group('SyncSpWalletUsecase leaves the scan to the user', () {
    test('does not scan with no cursor yet', () async {
      walletAt(null);

      await usecase.execute();

      expect(repo.scanOnceCount, 0);
    });

    test('does not scan while the tip is still unknown', () async {
      repo.chainTipValue = null;

      await usecase.execute();

      expect(repo.scanOnceCount, 0);
    });

    test('does not scan when the cursor is already at the tip', () async {
      walletAt(tip);

      await usecase.execute();

      expect(repo.scanOnceCount, 0);
    });

    test('does not scan when the cursor is ahead of the tip', () async {
      // The cursor follows the blindbit tip, chainTip follows the header
      // store, so it sits ahead while headers catch up.
      walletAt(tip + 10);

      await usecase.execute();

      expect(repo.scanOnceCount, 0);
    });

    test('does not scan when too far behind', () async {
      walletAt(tip - spAutoScanMaxBlocksBehind - 1);

      await usecase.execute();

      expect(repo.scanOnceCount, 0);
    });

    test(
      'does not scan when the wallet is gone or the gate is closed',
      () async {
        when(() => getWallet.execute()).thenAnswer((_) async => const Ok(null));

        final result = await usecase.execute();

        expect(result, isA<Ok<void, SpFailure>>());
        expect(repo.scanOnceCount, 0);
      },
    );

    test('does not scan while a scan is already running', () async {
      repo.setScanningForTest(true);

      final result = await usecase.execute();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(repo.scanOnceCount, 0);
    });
  });

  group('SyncSpWalletUsecase with auto scanning off', () {
    test('does not scan even when close to the tip', () async {
      autoScanRepo.save(isEnabled: false);
      walletAt(tip - 2);

      final result = await usecase.execute();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(repo.scanOnceCount, 0);
    });
  });

  group('SyncSpWalletUsecase serializes ticks', () {
    test('a tick arriving mid-flight joins the one already running', () async {
      // The tip watcher and the sync coordinator drive this independently, and
      // the isScanning check cannot separate them: two awaits elapse before
      // scanOnce sets the flag.
      final gate = Completer<void>();
      when(() => getWallet.execute()).thenAnswer((_) async {
        await gate.future;
        return Ok(spWallet(lastScannedHeight: tip - 10));
      });

      final first = usecase.execute();
      final second = usecase.execute();
      gate.complete();
      final results = await Future.wait([first, second]);

      expect(results.first, isA<Ok<void, SpFailure>>());
      expect(results.last, isA<Ok<void, SpFailure>>());
      verify(() => getWallet.execute()).called(1);
      expect(repo.scanOnceCount, 1);
    });

    test('a tick after the previous one settled runs again', () async {
      await usecase.execute();
      await usecase.execute();

      expect(repo.scanOnceCount, 2);
    });
  });

  group('SyncSpWalletUsecase leaves the electrum listener alone', () {
    test('a tick that scans does not restart the listener', () async {
      await usecase.execute();

      expect(repo.scanOnceCount, 1);
      expect(repo.restartElectrumCount, 0);
    });

    test('a tick that does not scan does not restart the listener', () async {
      walletAt(tip);

      await usecase.execute();

      expect(repo.scanOnceCount, 0);
      expect(repo.restartElectrumCount, 0);
    });
  });
}
