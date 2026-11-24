import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secrets;
import 'package:preferences/preferences.dart';
import 'package:silent/src/domain/entities/sp_coin.dart';
import 'package:silent/src/domain/entities/sp_notification.dart';
import 'package:silent/src/domain/ports/sp_account_files_port.dart';
import 'package:silent/src/domain/ports/sp_payments_port.dart';
import 'package:silent/src/domain/ports/sp_scan_control_port.dart';
import 'package:silent/src/domain/ports/sp_scan_port.dart';
import 'package:silent/src/domain/repositories/sp_account_repository.dart';
import 'package:silent/src/domain/repositories/sp_auto_scan_repository.dart';
import 'package:silent/src/domain/repositories/sp_backend_config_repository.dart';
import 'package:silent/src/presentation/sp_cubit.dart';
import 'package:silent/src/silent.dart';
import 'package:silent/src/silent_graph.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'sp_fakes.dart';

// The pure policy itself is covered in domain/sp_scan_policy_test.dart; this
// file checks that the Silent graph obeys it.
//
// Real-wiring SP scan policy. Unlike the cubit-only cubit_scan_test,
// this boots the SpCubit through the actual graph (LoadSpWalletData
// -> EnsureSpSession -> the account repository port) with ONLY the outbound
// repository port faked. FakeSpAccountRepository counts every scanOnce reaching
// the Rust boundary, so an accidental auto-scan anywhere in that chain trips the
// counter. Every case runs under fakeAsync and elapses a window wide enough for
// any stray timer- or lifecycle-driven scan to have fired.
//
// The sync tick is the one sanctioned automatic scan, so it is exercised here
// too: it must scan only when SpScanPolicy allows it.

class _MockSettingsRepository extends Mock implements Preferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GetIt locator;
  late FakeSpAccountRepository fakeRepo;
  late _MockSettingsRepository settingsRepo;
  late SpCubit cubit;

  setUp(() {
    fakeRepo = FakeSpAccountRepository(networkValue: BitcoinNetwork.mainnet);
    locator = GetIt.asNewInstance();
    locator.allowReassignment = true;

    // External collaborators SilentGraph's use cases resolve. The secret is never
    // read on this path (the fake reports a live session, so EnsureSpSession
    // returns the snapshot without reconstructing), but the graph resolves it.
    locator.registerSingleton<Secrets>(
      Secrets(scratchDirectory: () async => '/tmp'),
    );
    settingsRepo = _MockSettingsRepository();
    // The sync tick reads GetSpWalletUsecase, which checks the feature gate.
    when(() => settingsRepo.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
          isSuperuser: true,
        ).copyWith(isDevModeEnabled: true),
      ),
    );
    locator.registerSingleton<Preferences>(settingsRepo);

    // Real SP wiring: registers the whole use case + presentation graph.
    // A coordinator registration must not implicitly opt this isolated graph
    // into foreground watchers. Only composition grants that lifecycle fact.
    SilentGraph.setup(
      locator,
      readDefaultFingerprint: (_) async => const Ok(null),
    );

    // Swap ONLY the outbound ports for in-memory fakes. The lazy singletons are
    // not yet resolved, so the real BwkSpAccountRepository is never constructed.
    locator.registerSingleton<SpAccountRepository>(fakeRepo);
    locator.registerSingleton<SpAccountFilesPort>(fakeRepo);
    locator.registerSingleton<SpScanPort>(fakeRepo);
    locator.registerSingleton<SpScanControlPort>(fakeRepo);
    locator.registerSingleton<SpPaymentsPort>(fakeRepo);
    // The gate requires a stored config on the active network.
    final configRepo = FakeSpBackendConfigRepository();
    unawaited(
      configRepo.save(spBackendConfig(network: BitcoinNetwork.mainnet)),
    );
    locator.registerSingleton<SpBackendConfigRepository>(configRepo);
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

  group('SP scan policy (real Silent graph)', () {
    test(
      'regtest denies load and scan with an already stored SP account',
      () async {
        await cubit.load();
        when(() => settingsRepo.fetch()).thenAnswer(
          (_) async => Ok(
            const SettingsEntity(
              environment: Environment.regtest,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
              isSuperuser: true,
              isDevModeEnabled: true,
            ),
          ),
        );
        await cubit.load();
        await cubit.scan();
        expect(fakeRepo.scanOnceCount, 0);
        expect(fakeRepo.createCount, 0);
        expect(fakeRepo.hasSession, isTrue);
      },
    );

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
      unawaited(locator<SilentCapability>().syncWallet());
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
