import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/recreate_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_cubit_harness.dart';

class _MockSpAccountRepository extends Mock implements SpAccountRepository {}

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

MnemonicSeed _seed() => MnemonicSeed(
  mnemonicWords: List.filled(12, 'abandon'),
  bytes: Uint8List.fromList(List.filled(64, 1)),
  masterFingerprint: 'f23f9fd2',
);

SpBackendConfig _config() => SpBackendConfig(
  network: SpNetwork.regtest,
  blindbitUrl: 'http://blindbit.example',
  electrumUrl: 'tcp://electrum.example:50001',
);

SpWallet _wallet() => SpWallet(
  spAddress: 'sp1qexample',
  balance: SpBalance(
    confirmedSat: BigInt.from(10),
    totalUnifiedSat: BigInt.from(20),
  ),
  isScanning: false,
);

void main() {
  late _MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late _MockGetDefaultSeedUsecase getDefaultSeedUsecase;
  late EnsureSpSessionUsecase ensureSpSessionUsecase;
  late LoadSpWalletDataUsecase loadSpWalletDataUsecase;
  late RecreateSpWalletUsecase recreateSpWalletUsecase;
  late SpCubitHarness harness;
  late SpCubit cubit;

  // Stateful session mirror driven by the mock stubs.
  late bool hasSession;
  late bool teardown;
  late int createCount;
  late StreamController<SpNotification> notif;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(SpNetwork.regtest);
    registerFallbackValue(_config());
  });

  setUp(() {
    repository = _MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    getDefaultSeedUsecase = _MockGetDefaultSeedUsecase();

    // No account dir on disk, so no sentinel: ensure never treats the live
    // session as revoked.
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          return Directory.systemTemp.path;
        });

    hasSession = true;
    teardown = false;
    createCount = 0;
    notif = StreamController<SpNotification>.broadcast();

    when(() => repository.teardownInProgress).thenAnswer((_) => teardown);
    when(() => repository.hasSession).thenAnswer((_) => hasSession);
    when(() => repository.beginTeardown()).thenAnswer((_) {
      teardown = true;
    });
    when(() => repository.endTeardown()).thenAnswer((_) {
      teardown = false;
    });
    when(() => repository.dispose()).thenAnswer((_) async {
      hasSession = false;
      if (!notif.isClosed) await notif.close();
    });
    // No account dir on disk in this race harness, so backup/restore/discard
    // are no-ops; the session orchestration is what this test exercises.
    when(() => repository.backupAccountDir()).thenAnswer((_) async => false);
    when(() => repository.restoreAccountDir()).thenAnswer((_) async => false);
    when(() => repository.discardBackup()).thenAnswer((_) async {});
    when(
      () => repository.createFromMnemonic(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        mnemonic: any(named: 'mnemonic'),
      ),
    ).thenAnswer((_) async {
      // Mirror the adapter single-owner guard: a create over a live session is
      // the exact leak this test guards against.
      if (hasSession) {
        throw StateError('createFromMnemonic over a live session');
      }
      createCount++;
      hasSession = true;
      notif = StreamController<SpNotification>.broadcast();
    });
    when(() => repository.notifications).thenAnswer((_) => notif.stream);
    when(() => repository.snapshot()).thenReturn(_wallet());
    when(() => repository.history())
        .thenAnswer((_) async => Ok<List<SpPayment>, SpFailure>(<SpPayment>[]));
    when(() => repository.coins())
        .thenAnswer((_) async => const Ok<List<SpCoin>, SpFailure>([]));
    when(() => repository.network()).thenReturn(SpNetwork.regtest);
    when(() => repository.backendOnline()).thenReturn(true);
    when(() => repository.chainTip()).thenReturn(0);
    when(() => repository.minBirthdayHeight()).thenReturn(0);

    when(() => getDefaultSeedUsecase.execute()).thenAnswer((_) async => _seed());
    when(() => configRepository.fetch())
        .thenAnswer((_) async => Ok<SpBackendConfig?, SpFailure>(_config()));
    when(() => configRepository.save(any())).thenAnswer((_) async {});

    ensureSpSessionUsecase = EnsureSpSessionUsecase(
      repository: repository,
      configRepository: configRepository,
      getDefaultSeedUsecase: getDefaultSeedUsecase,
    );
    loadSpWalletDataUsecase = LoadSpWalletDataUsecase(
      repository: repository,
      ensureSpSessionUsecase: ensureSpSessionUsecase,
    );
    recreateSpWalletUsecase = RecreateSpWalletUsecase(
      getDefaultSeedUsecase: getDefaultSeedUsecase,
      repository: repository,
      configRepository: configRepository,
      ensureSpSessionUsecase: ensureSpSessionUsecase,
    );

    harness = SpCubitHarness();
    when(
      () => harness.watchUsecase.execute(),
    ).thenAnswer((_) => repository.notifications);
    cubit = SpCubit(
      loadSpWalletDataUsecase: loadSpWalletDataUsecase,
      watchSpNotificationsUsecase: harness.watchUsecase,
      scanSpWalletUsecase: harness.scanUsecase,
      stopSpScanUsecase: harness.stopUsecase,
      revokeSpWalletUsecase: harness.revokeUsecase,
      generateTaprootAddressUsecase: harness.generateUsecase,
    );
  });

  tearDown(() async {
    await cubit.close();
    if (!notif.isClosed) await notif.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  test('recreate with a subscribed cubit reaches createFromMnemonic once, no '
      'racing self-heal create (T1.2)', () async {
    // Subscribe the cubit to the live session (reuses it, no create).
    await cubit.load();
    await pumpEventQueue(times: 10);
    expect(createCount, 0, reason: 'a live session is reused, not recreated');

    // Recreate disposes (closing the notif stream, which triggers the cubit
    // self-heal) then creates the new session. The self-heal must not slip a
    // second createFromMnemonic through while teardown is in progress.
    final result = await recreateSpWalletUsecase.execute(
      network: SpNetwork.regtest,
      blindbitUrl: 'http://blindbit.new',
      electrumUrl: 'tcp://electrum.new:50001',
    );
    expect(result, isA<Ok<void, SpFailure>>());
    await pumpEventQueue(times: 50);

    expect(
      createCount,
      1,
      reason: 'exactly one create reaches the adapter during recreate',
    );
  });
}
