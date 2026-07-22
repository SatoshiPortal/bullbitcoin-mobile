import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../sp_cubit_harness.dart';
import '../sp_test_streams.dart';

void main() {
  late SpCubitHarness harness;
  late MockLoadSpWalletDataUsecase loadUsecase;
  late MockWatchSpNotificationsUsecase watchUsecase;
  late MockScanSpWalletUsecase scanUsecase;
  late MockRevokeSpWalletUsecase revokeUsecase;
  late MockGenerateTaprootAddressUsecase generateUsecase;
  late SpCubit cubit;

  final fakeBalance = SpBalance(
    confirmedSat: BigInt.from(10000),
    totalUnifiedSat: BigInt.from(10000),
  );

  SpWalletData buildData({
    SpBalance? balance,
    List<SpPayment>? history,
    int? lastScannedHeight = 800000,
    bool isScanning = false,
  }) => SpWalletData(
    wallet: SpWallet(
      spAddress: 'sp1qtest',
      balance: balance ?? fakeBalance,
      isScanning: isScanning,
      lastScannedHeight: lastScannedHeight,
    ),
    history: history ?? <SpPayment>[],
    coins: const [],
    network: SpNetwork.regtest,
    backendOnline: true,
  );

  SpCubit buildCubit() => harness.build();

  setUp(() {
    harness = SpCubitHarness();
    loadUsecase = harness.loadUsecase;
    watchUsecase = harness.watchUsecase;
    scanUsecase = harness.scanUsecase;
    revokeUsecase = harness.revokeUsecase;
    generateUsecase = harness.generateUsecase;

    when(
      () => loadUsecase.execute(),
    ).thenAnswer((_) async => Ok<SpWalletData, SpFailure>(buildData()));
    when(
      () => watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

    cubit = buildCubit();
  });

  tearDown(() async {
    await cubit.close();
  });

  test('initial state is empty', () {
    expect(cubit.state, const SpState());
  });

  test('load() populates address and balance fields from wallet', () async {
    await cubit.load();

    expect(cubit.state.spAddress, 'sp1qtest');
    expect(cubit.state.balance, fakeBalance);
    expect(cubit.state.history, isEmpty);
    expect(cubit.state.lastScannedHeight, 800000);
    expect(cubit.state.isScanning, false);
    expect(cubit.state.isLoading, false);
    expect(cubit.state.network, SpNetwork.regtest);
    expect(cubit.state.backendOnline, true);
  });

  test('load() sets isLoading to false after completion', () async {
    await cubit.load();
    // Check state directly; avoids relying on stream delivery timing.
    expect(cubit.state.isLoading, false);
  });

  test('totalBalance getter returns totalUnifiedSat from balance', () async {
    await cubit.load();
    expect(cubit.state.totalBalance, BigInt.from(10000));
  });

  test('load() sets error on wallet access failure', () async {
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async =>
          const Err<SpWalletData, SpFailure>(SpUnexpected('wallet error')),
    );

    await cubit.load();

    expect(cubit.state.error, isNotNull);
    expect(cubit.state.isLoading, false);
  });

  test('load() subscribes to watchSpNotificationsUsecase', () async {
    await cubit.load();
    verify(() => watchUsecase.execute()).called(1);
  });

  test('load() applies replayed header validation notification', () async {
    when(() => watchUsecase.execute()).thenAnswer(
      (_) => Stream<SpNotification>.value(
        const SpHeaderProgressCompleted(SpHeaderValidationPhase.replay),
      ),
    );

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.headerValidationStatus, SpHeaderValidationStatus.valid);
    expect(cubit.state.headerValidationPhase, SpHeaderValidationPhase.replay);
  });

  test(
    'load() keeps notifications live when wallet data is partially broken',
    () async {
      final controller = StreamController<SpNotification>.broadcast();
      addTearDown(controller.close);
      when(() => loadUsecase.execute()).thenAnswer(
        (_) async => const Err<SpWalletData, SpFailure>(
          SpUnexpected('history decode failed'),
        ),
      );
      when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);

      await cubit.load();
      await Future<void>.delayed(Duration.zero);
      controller.add(
        const SpHeaderProgressCompleted(SpHeaderValidationPhase.initialSync),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.error, isA<SpUnexpected>());
      expect(
        cubit.state.headerValidationStatus,
        SpHeaderValidationStatus.valid,
      );
      expect(
        cubit.state.headerValidationPhase,
        SpHeaderValidationPhase.initialSync,
      );
    },
  );

  test(
    'recreated cubit subscribes to the same broadcast stream (no init reuse)',
    () async {
      // Regression for: after first cubit closes (route leave), a second
      // cubit (route re-entry) must still receive notifications. The usecase
      // exposes a broadcast stream so both subscribe without depleting the
      // single-take Rust receiver.
      final controller = StreamController<SpNotification>.broadcast();
      addTearDown(controller.close);
      when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);

      // First cubit
      await cubit.load();
      final firstEvents = <SpNotification>[];
      final firstStateSub = cubit.stream.listen((s) {
        if (s.isScanning) {
          firstEvents.add(const SpScanStarted(1, 2));
        }
      });
      controller.add(const SpScanStarted(1, 2));
      await Future<void>.delayed(Duration.zero);
      expect(firstEvents, isNotEmpty);
      await firstStateSub.cancel();
      await cubit.close();

      // Second cubit on the same notification stream
      final cubit2 = buildCubit();
      addTearDown(cubit2.close);

      await cubit2.load();
      controller.add(const SpScanStarted(10, 20));
      await Future<void>.delayed(Duration.zero);
      expect(cubit2.state.isScanning, true);
      expect(cubit2.state.scanFrom, 10);
      expect(cubit2.state.scanTo, 20);
    },
  );

  test('ScanSpWalletUsecase is never called during load()', () async {
    await cubit.load();
    verifyNever(() => scanUsecase.execute());
  });

  group('generateTaprootAddress', () {
    test(
      'each call reveals a fresh address via the usecase and updates state',
      () async {
        var calls = 0;
        when(() => generateUsecase.execute()).thenAnswer((_) async {
          calls++;
          return Ok<String, SpFailure>(
            calls == 1 ? 'bcrt1pfirst' : 'bcrt1psecond',
          );
        });

        await cubit.generateTaprootAddress();
        expect(cubit.state.taprootReceiveAddress, 'bcrt1pfirst');
        expect(cubit.state.isGeneratingAddress, false);

        await cubit.generateTaprootAddress();
        expect(cubit.state.taprootReceiveAddress, 'bcrt1psecond');
        expect(cubit.state.isGeneratingAddress, false);

        verify(() => generateUsecase.execute()).called(2);
      },
    );

    test('sets error and clears isGeneratingAddress on failure', () async {
      when(() => generateUsecase.execute()).thenAnswer(
        (_) async =>
            const Err<String, SpFailure>(SpUnexpected('derive failed')),
      );

      await cubit.generateTaprootAddress();

      expect(cubit.state.error, isNotNull);
      expect(cubit.state.isGeneratingAddress, false);
    });
  });

  group('revokeWallet', () {
    test('delegates to the revoke usecase', () async {
      when(
        () => revokeUsecase.execute(),
      ).thenAnswer((_) async => const Ok(null));

      await cubit.revokeWallet();

      verify(() => revokeUsecase.execute()).called(1);
    });

    test(
      'completes when the usecase returns Err (UI must still navigate)',
      () async {
        when(
          () => revokeUsecase.execute(),
        ).thenAnswer((_) async => const Err(SpUnexpected('delete failed')));

        // The usecase already makes the wallet unloadable (sentinel) even on its
        // failure path, so revokeWallet must complete instead of propagating.
        await expectLater(cubit.revokeWallet(), completes);
      },
    );
  });
}
