import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_payments_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_control_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_auto_scan_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/sp/sp_locator.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'sp_fakes.dart';

// The pure policy itself is covered in domain/sp_scan_policy_test.dart; this
// file checks the sp_locator-wired graph obeys it.
//
// Real-wiring SP scan policy. Unlike the cubit-only cubit_scan_test,
// this boots the SpCubit through the actual `sp_locator` graph (LoadSpWalletData
// -> EnsureSpSession -> the account repository port) with ONLY the outbound
// repository port faked. FakeSpAccountRepository counts every scanOnce reaching
// the Rust boundary, so an accidental auto-scan anywhere in that chain trips the
// counter. Every case runs under fakeAsync and elapses a window wide enough for
// any stray timer- or lifecycle-driven scan to have fired.
//
// The sync tick is the one sanctioned automatic scan, so it is exercised here
// too: it must scan only when SpScanPolicy allows it.

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GetIt locator;
  late FakeSpAccountRepository fakeRepo;
  late _MockSettingsRepository settingsRepo;
  late SpCubit cubit;

  setUp(() {
    fakeRepo = FakeSpAccountRepository();
    locator = GetIt.asNewInstance();
    locator.allowReassignment = true;

    // External collaborators SpLocator's use cases resolve. The seed is never
    // read on this path (the fake reports a live session, so EnsureSpSession
    // returns the snapshot without reconstructing), but the graph resolves it.
    locator.registerSingleton<GetDefaultSeedUsecase>(
      MockGetDefaultSeedUsecase(),
    );
    settingsRepo = _MockSettingsRepository();
    // The sync tick reads GetSpWalletUsecase, which checks the feature gate.
    when(() => settingsRepo.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
        isSuperuser: true,
      ).copyWith(isDevModeEnabled: true),
    );
    locator.registerSingleton<SettingsRepository>(settingsRepo);

    // Real SP wiring: registers the whole use case + presentation graph.
    SpLocator.setup(locator);

    // Swap ONLY the outbound ports for in-memory fakes. The lazy singletons are
    // not yet resolved, so the real BwkSpAccountRepository is never constructed.
    locator.registerSingleton<SpAccountRepository>(fakeRepo);
    locator.registerSingleton<SpAccountFilesPort>(fakeRepo);
    locator.registerSingleton<SpScanPort>(fakeRepo);
    locator.registerSingleton<SpScanControlPort>(fakeRepo);
    locator.registerSingleton<SpPaymentsPort>(fakeRepo);
    locator.registerSingleton<SpBackendConfigRepository>(
      FakeSpBackendConfigRepository(),
    );
    locator.registerSingleton<SpAutoScanRepository>(FakeSpAutoScanRepository());

    cubit = locator<SpCubit>();
  });

  tearDown(() async {
    await cubit.close();
    await fakeRepo.disposeStreams();
    await locator.reset();
  });

  // Wide enough that any stray timer- or lifecycle-driven scan would have
  // fired, elapsed virtually so the result does not depend on machine load.
  const settleWindow = Duration(milliseconds: 200);

  group('SP scan policy (real sp_locator wiring)', () {
    test('load() through the real graph never reaches scanOnce', () {
      fakeAsync((async) {
        expect(fakeRepo.scanOnceCount, 0);

        unawaited(cubit.load());
        async.elapse(settleWindow);

        expect(fakeRepo.scanOnceCount, 0);
      });
    });

    test('inbound notifications (electrum tx / new output / scan completed) '
        'never trigger a scan', () {
      fakeAsync((async) {
        unawaited(cubit.load());
        async.flushMicrotasks();

        fakeRepo.emitNotification(
          SpElectrumTx(
            kind: SpCoinSource.segwit,
            txid: 'aabbcc',
            amountSat: Sats.fromInt(1000),
          ),
        );
        fakeRepo.emitNotification(SpNewOutput('abc:0', Sats.zero));
        fakeRepo.emitNotification(const SpScanCompleted());
        async.elapse(settleWindow);

        expect(fakeRepo.scanOnceCount, 0);
      });
    });

    test('only an explicit user scan() reaches scanOnce, exactly once', () {
      fakeAsync((async) {
        unawaited(cubit.load());
        async.elapse(settleWindow);
        expect(fakeRepo.scanOnceCount, 0);

        unawaited(cubit.scan());
        async.elapse(settleWindow);

        expect(fakeRepo.scanOnceCount, 1);
      });
    });
  });

  group('sync tick through the real graph', () {
    void syncTick(FakeAsync async) {
      unawaited(locator<SpFacade>().syncWallet());
      async.elapse(settleWindow);
    }

    test('does not scan with no cursor yet', () {
      fakeAsync((async) {
        fakeRepo.setWalletForTest(spWallet());
        fakeRepo.chainTipValue = 900000;

        syncTick(async);

        expect(fakeRepo.scanOnceCount, 0);
      });
    });

    test('does not scan when the wallet is far behind the tip', () {
      fakeAsync((async) {
        fakeRepo.setWalletForTest(spWallet(lastScannedHeight: 800000));
        fakeRepo.chainTipValue = 900000;

        syncTick(async);

        expect(fakeRepo.scanOnceCount, 0);
      });
    });

    test('scans exactly once when the wallet is close to the tip', () {
      fakeAsync((async) {
        fakeRepo.setWalletForTest(spWallet(lastScannedHeight: 899990));
        fakeRepo.chainTipValue = 900000;

        syncTick(async);

        expect(fakeRepo.scanOnceCount, 1);
      });
    });
  });
}
