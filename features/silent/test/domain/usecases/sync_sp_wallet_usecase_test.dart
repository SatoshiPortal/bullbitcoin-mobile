import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/get_sp_auto_scan_usecase.dart';
import 'package:silent/src/domain/sp_scan_policy.dart';
import 'package:silent/src/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:silent/src/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/sync_sp_wallet_usecase.dart';
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
  late bool isForeground;

  SyncSpWalletUsecase build() => SyncSpWalletUsecase(
    repository: repo,
    getSpWalletUsecase: getWallet,
    isSpScanningUsecase: IsSpScanningUsecase(repository: repo),
    scanSpWalletUsecase: ScanSpWalletUsecase(
      getSpFeatureGateUsecase: FakeSpFeatureGateUsecase(),
      repository: repo,
    ),
    getSpAutoScanUsecase: GetSpAutoScanUsecase(repository: autoScanRepo),
    isForeground: () => isForeground,
  );

  void walletAt(
    int? lastScannedHeight, {
    bool hasPendingScan = false,
    bool isPendingScanPaused = false,
  }) {
    when(() => getWallet.execute()).thenAnswer(
      (_) async => Ok(
        spWallet(
          lastScannedHeight: lastScannedHeight,
          hasPendingScan: hasPendingScan,
          isPendingScanPaused: isPendingScanPaused,
        ),
      ),
    );
  }

  setUp(() {
    repo = FakeSpAccountRepository();
    repo.chainTipValue = tip;
    getWallet = _MockGetSpWalletUsecase();
    autoScanRepo = FakeSpAutoScanRepository();
    isForeground = true;
    // Default: a wallet a few blocks behind, i.e. one a tick would scan.
    walletAt(tip - 10);
    usecase = build();
  });

  group('SyncSpWalletUsecase resumes the scan', () {
    test('scans when the cursor is close enough to the tip', () async {
      walletAt(tip - 10);

      final result = await usecase.execute();

      expect(result, isA<Ok<void, SilentFailure>>());
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

  group('SyncSpWalletUsecase resumes a pending scan', () {
    test('resumes a pending scan the policy would decline', () async {
      // Far behind the tip: `SpScanPolicy` would leave this to the user, but
      // the wallet already had a scan in flight, so it continues.
      walletAt(tip - spAutoScanMaxBlocksBehind - 1, hasPendingScan: true);

      final result = await usecase.execute();

      expect(result, isA<Ok<void, SilentFailure>>());
      expect(repo.scanOnceCount, 1);
    });

    test('resumes a pending scan with no cursor yet', () async {
      walletAt(null, hasPendingScan: true);

      await usecase.execute();

      expect(repo.scanOnceCount, 1);
    });

    test('never resumes a pending scan the user stopped', () async {
      walletAt(tip - 10, hasPendingScan: true, isPendingScanPaused: true);

      await usecase.execute();

      expect(repo.scanOnceCount, 0);
    });

    test('honours the automatic scanning setting', () async {
      autoScanRepo.save(isEnabled: false);
      walletAt(tip - 10, hasPendingScan: true);

      await usecase.execute();

      expect(repo.scanOnceCount, 0);
    });
  });

  group('SyncSpWalletUsecase resume-only retries', () {
    test('resumes a pending scan without consulting the policy', () async {
      walletAt(tip, hasPendingScan: true);

      await usecase.execute(resumeOnly: true);

      expect(repo.scanOnceCount, 1);
    });

    test('never starts a fresh scan from the policy', () async {
      walletAt(tip - 10);

      await usecase.execute(resumeOnly: true);

      expect(repo.scanOnceCount, 0);
    });
  });

  group('SyncSpWalletUsecase automatic admission', () {
    test('a decision whose revision moved on is refused', () async {
      // A full tick reads the revision, then the session is recycled before
      // the repository sees the launch: the state that decision belonged to is
      // gone, so it must not scan.
      walletAt(tip - 10);
      repo.beforeScanOnce = () => repo.scanRevisionValue++;

      final result = await usecase.execute();

      expect(result, isA<Ok<void, SilentFailure>>());
      expect(repo.scanOnceCount, 0);
      expect(repo.automaticRefusals, 1);
    });
  });

  group('SyncSpWalletUsecase only runs in the foreground', () {
    test('does not even read the wallet in the background', () async {
      isForeground = false;

      final result = await usecase.execute();

      expect(result, isA<Ok<void, SilentFailure>>());
      verifyNever(() => getWallet.execute());
      expect(repo.scanOnceCount, 0);
    });

    test('scans again once the app is back in front', () async {
      isForeground = false;
      await usecase.execute();
      isForeground = true;

      await usecase.execute();

      expect(repo.scanOnceCount, 1);
    });

    test(
      'does not scan if the app backgrounds while reading the wallet',
      () async {
        final reading = Completer<void>();
        final release = Completer<void>();
        when(() => getWallet.execute()).thenAnswer((_) async {
          reading.complete();
          await release.future;
          return Ok(spWallet(lastScannedHeight: tip - 10));
        });

        final sync = usecase.execute();
        await reading.future;
        isForeground = false;
        release.complete();
        await sync;

        expect(repo.scanOnceCount, 0);
      },
    );
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

        expect(result, isA<Ok<void, SilentFailure>>());
        expect(repo.scanOnceCount, 0);
      },
    );

    test('does not scan while a scan is already running', () async {
      repo.setScanningForTest(true);

      final result = await usecase.execute();

      expect(result, isA<Ok<void, SilentFailure>>());
      expect(repo.scanOnceCount, 0);
    });
  });

  group('SyncSpWalletUsecase with auto scanning off', () {
    test('does not scan even when close to the tip', () async {
      autoScanRepo.save(isEnabled: false);
      walletAt(tip - 2);

      final result = await usecase.execute();

      expect(result, isA<Ok<void, SilentFailure>>());
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

      expect(results.first, isA<Ok<void, SilentFailure>>());
      expect(results.last, isA<Ok<void, SilentFailure>>());
      verify(() => getWallet.execute()).called(1);
      expect(repo.scanOnceCount, 1);
    });

    test('a full tick behind a resume-only one still gets its turn', () async {
      final gate = Completer<void>();
      when(() => getWallet.execute()).thenAnswer((_) async {
        await gate.future;
        return Ok(spWallet(lastScannedHeight: tip - 10));
      });

      final retry = usecase.execute(resumeOnly: true);
      final tick = usecase.execute();
      gate.complete();
      await Future.wait([retry, tick]);

      // The retry found nothing to resume, and the queued tick still judged
      // the policy instead of being dropped.
      expect(repo.automaticRefusals, 0);
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
