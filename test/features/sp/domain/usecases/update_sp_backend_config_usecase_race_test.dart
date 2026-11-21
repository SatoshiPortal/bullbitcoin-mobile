import 'package:bb_mobile/features/sp/watchers/sp_header_retry_watcher.dart';

import 'dart:async';

import 'package:bb_mobile/features/sp/domain/usecases/is_sp_scanning_usecase.dart';

import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/watchers/sp_notifications_watcher.dart';
import 'package:bb_mobile/features/sp/domain/usecases/clear_sp_scan_state_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/update_sp_backend_config_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart' show Secret;

import '../../sp_cubit_harness.dart';
import '../../sp_fakes.dart';

import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';

// UpdateSpBackendConfigUsecase with a live cubit subscribed to the session it
// tears down. The plain orchestration cases live in
// update_sp_backend_config_usecase_test.dart.
class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

void main() {
  late MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late MockGetSpSecretUsecase getSpSecretUsecase;
  late Secret secret;
  late EnsureSpSessionUsecase ensureSpSessionUsecase;
  late LoadSpWalletDataUsecase loadSpWalletDataUsecase;
  late UpdateSpBackendConfigUsecase updateSpBackendConfigUsecase;
  late RevokeSpWalletUsecase revokeSpWalletUsecase;
  late SpSessionGuard guard;
  late SpCubitHarness harness;
  late SpCubit cubit;

  // Stateful session mirror driven by the mock stubs.
  late bool hasSession;
  late bool teardown;
  late int createCount;
  late StreamController<SpNotification> notif;

  setUpAll(() async {
    registerFallbackValue(await spSecret());
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(BitcoinNetwork.testnet);
    registerFallbackValue(spBackendConfig());
  });

  setUp(() async {
    secret = await spSecret();
    repository = MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    getSpSecretUsecase = MockGetSpSecretUsecase();
    // One guard, as the locator registers it: it is what keeps a recreate and
    // a revoke off the same session.
    guard = SpSessionGuard();

    hasSession = true;
    teardown = false;
    createCount = 0;
    notif = StreamController<SpNotification>.broadcast();
    when(() => repository.hasSession).thenAnswer((_) => hasSession);
    when(() => repository.teardownInProgress).thenAnswer((_) => teardown);
    when(() => repository.beginTeardown()).thenAnswer((_) {
      teardown = true;
    });
    when(() => repository.endTeardown()).thenAnswer((_) {
      teardown = false;
    });
    when(() => repository.dispose()).thenAnswer((_) async {
      hasSession = false;
      if (!notif.isClosed) await notif.close();
      return const Ok(null);
    });
    when(() => repository.adoptNewestBackup())
        .thenAnswer((_) async => const Ok(false));
    when(() => repository.hasRevokedSentinel())
        .thenAnswer((_) async => const Ok(false));
    when(() => repository.isScanningCached).thenReturn(false);
    when(() => repository.accountDirExists())
        .thenAnswer((_) async => const Ok(true));
    when(
      () => repository.writeRevokedSentinel(
        skipIfPresent: any(named: 'skipIfPresent'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(() => repository.deleteOrphanBackups())
        .thenAnswer((_) async => const Ok(null));
    when(() => repository.deleteAccountDir())
        .thenAnswer((_) async => const Ok(null));
    when(() => repository.notifySetupChanged()).thenReturn(null);
    when(() => configRepository.setIsSetUpNow(isSetUp: false)).thenReturn(null);
    when(() => configRepository.delete())
        .thenAnswer((_) async => const Ok(null));
    when(
      () => repository.createFromSecret(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        secret: any(named: 'secret'),
      ),
    ).thenAnswer((_) async {
      // Mirror the adapter single-owner guard: a create over a live session is
      // the exact leak this test guards against.
      if (hasSession) {
        throw StateError('createFromSecret over a live session');
      }
      createCount++;
      hasSession = true;
      notif = StreamController<SpNotification>.broadcast();
      return const Ok(null);
    });
    when(() => repository.notifications).thenAnswer((_) => notif.stream);
    when(() => repository.snapshot()).thenReturn(Ok(spWallet()));
    when(() => repository.history())
        .thenAnswer((_) async => Ok<List<SpPayment>, SpFailure>(<SpPayment>[]));
    when(() => repository.coins())
        .thenAnswer((_) async => const Ok<List<SpCoin>, SpFailure>([]));
    when(() => repository.network()).thenReturn(Ok(BitcoinNetwork.testnet));
    when(() => repository.chainTip()).thenReturn(0);
    when(() => repository.minBirthdayHeight()).thenReturn(const Ok(0));

    when(() => getSpSecretUsecase.execute(any()))
        .thenAnswer((_) async => Ok(secret));
    when(() => configRepository.fetch()).thenAnswer(
      (_) async => Ok<SpBackendConfig?, SpFailure>(
        spBackendConfig(network: BitcoinNetwork.testnet),
      ),
    );
    when(() => configRepository.save(any()))
        .thenAnswer((_) async => const Ok(null));

    ensureSpSessionUsecase = EnsureSpSessionUsecase(
      getSpFeatureGateUsecase: FakeSpFeatureGateUsecase(),
      repository: repository,
      files: repository,
      configRepository: configRepository,
      getSpSecretUsecase: getSpSecretUsecase,
    );
    loadSpWalletDataUsecase = LoadSpWalletDataUsecase(
      repository: repository,
      ensureSpSessionUsecase: ensureSpSessionUsecase,
    );
    updateSpBackendConfigUsecase = UpdateSpBackendConfigUsecase(
      getSpFeatureGateUsecase: FakeSpFeatureGateUsecase(),
      getSpSecretUsecase: getSpSecretUsecase,
      repository: repository,
      files: repository,
      configRepository: configRepository,
      ensureSpSessionUsecase: ensureSpSessionUsecase,
      isSpScanningUsecase: IsSpScanningUsecase(repository: repository),
      guard: guard,
    );
    revokeSpWalletUsecase = RevokeSpWalletUsecase(
      repository: repository,
      files: repository,
      configRepository: configRepository,
      guard: guard,
    );

    harness = SpCubitHarness();
    when(() => harness.watchUsecase.execute())
        .thenAnswer((_) => repository.notifications);
    cubit = SpCubit(
      loadSpWalletDataUsecase: loadSpWalletDataUsecase,
      restampSpPaymentTimesUsecase: harness.restampUsecase,
      spNotificationsWatcher: SpNotificationsWatcher(
        watchSpNotificationsUsecase: harness.watchUsecase,
        ensureSpSessionUsecase: ensureSpSessionUsecase,
      ),
      scanSpWalletUsecase: harness.scanUsecase,
      isSpScanningUsecase: IsSpScanningUsecase(repository: repository),
      stopSpScanUsecase: harness.stopUsecase,
      clearSpScanStateUsecase: ClearSpScanStateUsecase(repository: repository),
      revokeSpWalletUsecase: harness.revokeUsecase,
      generateTaprootAddressUsecase: harness.generateUsecase,
      headerRetryWatcher: SpHeaderRetryWatcher(
        resyncSpListenerUsecase: harness.resyncUsecase,
      ),
      setSpAutoScanUsecase: harness.autoScanUsecase,
      getSpAutoScanUsecase: harness.getAutoScanUsecase,
    );
  });

  tearDown(() async {
    await cubit.close();
    if (!notif.isClosed) await notif.close();
  });

  test('recreate with a subscribed cubit reaches createFromSecret once, no '
      'racing self-heal create', () async {
    // Subscribe the cubit to the live session (reuses it, no create).
    await cubit.load();
    await pumpEventQueue(times: 10);
    expect(createCount, 0, reason: 'a live session is reused, not recreated');

    // Recreate disposes (closing the notif stream, which triggers the cubit
    // self-heal) then creates the new session. The self-heal must not slip a
    // second createFromSecret through while teardown is in progress.
    final result = await updateSpBackendConfigUsecase.execute(
      network: BitcoinNetwork.testnet,
      blindbitUrl: 'http://blindbit.new',
      electrumUrl: 'tcp://electrum.new:50001',
    );
    expect(result, const Ok<bool, SpFailure>(true));
    await pumpEventQueue(times: 50);

    expect(
      createCount,
      1,
      reason: 'exactly one create reaches the adapter during recreate',
    );
  });

  test('a revoke started mid-recreate waits instead of interleaving', () async {
    // The two are reachable at once from different screens: the SP settings
    // save drives the recreate, turning developer mode off drives the revoke.
    final order = <String>[];
    when(() => repository.deleteAccountDir()).thenAnswer((_) async {
      order.add('revoke');
      return const Ok(null);
    });

    final recreate = updateSpBackendConfigUsecase.execute(
      network: BitcoinNetwork.testnet,
      blindbitUrl: 'http://blindbit.new',
      electrumUrl: 'tcp://electrum.new:50001',
    );
    // Started while the recreate is mid-flight, not queued behind its future.
    final revoke = revokeSpWalletUsecase.execute();

    expect(await recreate, const Ok<bool, SpFailure>(true));
    order.add('recreate done');
    expect(await revoke, isA<Ok<void, SpFailure>>());
    await pumpEventQueue(times: 50);

    expect(order, [
      'recreate done',
      'revoke',
    ], reason: 'the revoke waits for the recreate to finish rebuilding');
    expect(createCount, 1, reason: 'the revoke never races a second create');
  });
}
