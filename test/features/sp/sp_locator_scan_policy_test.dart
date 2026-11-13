import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';

import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:secrets/secrets.dart' show Secrets;
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
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
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
// counter. Every case uses the widget test clock and elapses a window wide enough for
// any stray timer- or lifecycle-driven scan to have fired.
//
// The sync tick is the one sanctioned automatic scan, so it is exercised here
// too: it must scan only when SpScanPolicy allows it.

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GetIt locator;
  late FakeSpAccountRepository fakeRepo;
  late _MockSettingsRepository settingsRepo;
  late SpCubit cubit;

  Future<void> runWithFixture(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    fakeRepo = FakeSpAccountRepository();
    locator = GetIt.asNewInstance();
    locator.allowReassignment = true;

    // External collaborators SpLocator's use cases resolve. The secret is never
    // read on this path (the fake reports a live session, so EnsureSpSession
    // returns the snapshot without reconstructing), but the graph resolves it.
    locator.registerSingleton<WalletMutationGuard>(WalletMutationGuard());
    locator.registerSingleton<WalletRepository>(_MockWalletRepository());
    locator.registerSingleton<Secrets>(
      Secrets(scratchDirectory: () async => '/tmp'),
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

    Object? bodyError;
    StackTrace? bodyStack;
    Object? cleanupError;
    StackTrace? cleanupStack;
    var cleanupComplete = false;
    var cleanupStage = 'cubit.close';
    String? cleanupFailureStage;
    try {
      await body();
    } catch (error, stack) {
      bodyError = error;
      bodyStack = stack;
    } finally {
      try {
        await tester.runAsync(() async {
          try {
            await (() async {
              await cubit.close();
              cleanupStage = 'repository.disposeStreams';
              await fakeRepo.disposeStreams();
              cleanupStage = 'locator.reset';
              await locator.reset();
              cleanupStage = 'complete';
              cleanupComplete = true;
            }()).timeout(const Duration(seconds: 5));
          } catch (error, stack) {
            cleanupError = error;
            cleanupStack = stack;
            cleanupFailureStage = cleanupStage;
          }
        });
        expect(
          cleanupComplete,
          isTrue,
          reason: 'Fixture cleanup must complete; stage=$cleanupStage',
        );
      } catch (error, stack) {
        cleanupError ??= error;
        cleanupStack ??= stack;
        cleanupFailureStage ??= cleanupStage;
      }
      if (cleanupError != null) {
        final frames = bodyError == null
            ? ''
            : cleanupStack
                  .toString()
                  .split('\n')
                  .where((line) => line.trimLeft().startsWith('#'))
                  .join('\n');
        debugPrintSynchronously(
          'SP_FIXTURE_CLEANUP type=${cleanupError.runtimeType} stage=${cleanupFailureStage ?? cleanupStage}\n$frames',
        );
      }
    }
    final primary = bodyError;
    if (primary != null) {
      Error.throwWithStackTrace(primary, bodyStack ?? StackTrace.current);
    }
    final secondary = cleanupError;
    if (secondary != null) {
      Error.throwWithStackTrace(secondary, cleanupStack ?? StackTrace.current);
    }
  }

  // Wide enough that any stray timer- or lifecycle-driven scan would have
  // fired, elapsed virtually so the result does not depend on machine load.
  const settleWindow = Duration(milliseconds: 200);

  Future<T> finishInWindow<T>(
    WidgetTester tester,
    Future<T> operation,
    Duration window,
    String label,
  ) async {
    var complete = false;
    late T value;
    Object? operationError;
    StackTrace? operationStack;
    final observed = operation.then<void>(
      (result) {
        value = result;
        complete = true;
      },
      onError: (Object error, StackTrace stack) {
        operationError = error;
        operationStack = stack;
        complete = true;
      },
    );
    await tester.pump(window);
    final error = operationError;
    if (error != null) {
      Error.throwWithStackTrace(error, operationStack ?? StackTrace.current);
    }
    expect(complete, isTrue, reason: '$label must complete');
    await observed;
    return value;
  }

  Future<void> completeLoad(
    WidgetTester tester, {
    bool initialPump = false,
  }) async {
    await finishInWindow<void>(
      tester,
      cubit.load(),
      initialPump ? Duration.zero : settleWindow,
      'load',
    );
    expect(cubit.state.error, isNull);
  }

  Future<void> syncTick(WidgetTester tester) async {
    final result = await finishInWindow(
      tester,
      locator<SpFacade>().syncWallet(),
      settleWindow,
      'sync tick',
    );
    expect(result, isA<Ok<void, SpFailure>>());
  }

  group('SP scan policy (real sp_locator wiring)', () {
    testWidgets('load() through the real graph never reaches scanOnce', (
      tester,
    ) async {
      await runWithFixture(tester, () async {
        expect(fakeRepo.scanOnceCount, 0);
        await completeLoad(tester);
        expect(fakeRepo.scanOnceCount, 0);
      });
    });

    testWidgets(
      'inbound notifications (electrum tx / new output / scan completed) never trigger a scan',
      (tester) async {
        await runWithFixture(tester, () async {
          await completeLoad(tester, initialPump: true);
          fakeRepo.emitNotification(
            SpElectrumTx(
              kind: SpCoinSource.segwit,
              txid: 'aabbcc',
              amountSat: Sats.fromInt(1000),
            ),
          );
          fakeRepo.emitNotification(SpNewOutput('abc:0', Sats.zero));
          fakeRepo.emitNotification(const SpScanCompleted());
          await tester.pump(settleWindow);
          expect(fakeRepo.scanOnceCount, 0);
        });
      },
    );

    testWidgets('only an explicit user scan() reaches scanOnce, exactly once', (
      tester,
    ) async {
      await runWithFixture(tester, () async {
        await completeLoad(tester, initialPump: true);
        expect(fakeRepo.scanOnceCount, 0);
        await finishInWindow<void>(tester, cubit.scan(), settleWindow, 'scan');
        expect(cubit.state.error, isNull);
        expect(fakeRepo.scanOnceCount, 1);
      });
    });
  });

  group('sync tick through the real graph', () {
    testWidgets('does not scan with no cursor yet', (tester) async {
      await runWithFixture(tester, () async {
        fakeRepo.setWalletForTest(spWallet());
        fakeRepo.chainTipValue = 900000;
        await syncTick(tester);
        expect(fakeRepo.scanOnceCount, 0);
      });
    });

    testWidgets('does not scan when the wallet is far behind the tip', (
      tester,
    ) async {
      await runWithFixture(tester, () async {
        fakeRepo.setWalletForTest(spWallet(lastScannedHeight: 800000));
        fakeRepo.chainTipValue = 900000;
        await syncTick(tester);
        expect(fakeRepo.scanOnceCount, 0);
      });
    });

    testWidgets('scans exactly once when the wallet is close to the tip', (
      tester,
    ) async {
      await runWithFixture(tester, () async {
        fakeRepo.setWalletForTest(spWallet(lastScannedHeight: 899990));
        fakeRepo.chainTipValue = 900000;
        await syncTick(tester);
        expect(fakeRepo.scanOnceCount, 1);
      });
    });
  });
}
