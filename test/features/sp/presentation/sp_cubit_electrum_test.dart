import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../sp_cubit_harness.dart';

void main() {
  late SpCubitHarness harness;
  late MockLoadSpWalletDataUsecase loadUsecase;
  late MockWatchSpNotificationsUsecase watchUsecase;
  late MockScanSpWalletUsecase scanUsecase;
  late SpCubit cubit;
  late StreamController<SpNotification> notifController;

  final fakeBalance = SpBalance(
    confirmedSat: BigInt.from(3000),
    totalUnifiedSat: BigInt.from(3000),
  );

  SpWalletData buildData() => SpWalletData(
    wallet: SpWallet(
      spAddress: 'sp1qtest',
      balance: fakeBalance,
      isScanning: false,
      lastScannedHeight: null,
    ),
    history: <SpPayment>[],
    coins: const [],
    network: SpNetwork.regtest,
    backendOnline: true,
  );

  setUp(() {
    harness = SpCubitHarness();
    loadUsecase = harness.loadUsecase;
    watchUsecase = harness.watchUsecase;
    scanUsecase = harness.scanUsecase;
    notifController = StreamController<SpNotification>.broadcast();

    when(() => loadUsecase.execute())
        .thenAnswer((_) async => Ok<SpWalletData, SpFailure>(buildData()));
    when(
      () => watchUsecase.execute(),
    ).thenAnswer((_) => notifController.stream);

    cubit = harness.build();
  });

  tearDown(() async {
    await cubit.close();
    await notifController.close();
  });

  test('ElectrumTx notification triggers wallet data reload', () async {
    await cubit.load();
    clearInteractions(loadUsecase);

    notifController.add(
      SpElectrumTx(
        kind: SpCoinSource.segwit,
        txid: 'aabbcc',
        amountSat: BigInt.from(1000),
      ),
    );
    await Future.delayed(Duration.zero);

    verify(() => loadUsecase.execute()).called(greaterThanOrEqualTo(1));
  });

  test(
    'ElectrumTx notification does NOT invoke ScanSpWalletUsecase.execute',
    () async {
      await cubit.load();

      notifController.add(
        SpElectrumTx(
          kind: SpCoinSource.segwit,
          txid: 'aabbcc',
          amountSat: BigInt.from(1000),
        ),
      );
      await Future.delayed(Duration.zero);

      verifyNever(() => scanUsecase.execute());
    },
  );

  test('NewOutput notification triggers data reload without scan', () async {
    await cubit.load();
    clearInteractions(loadUsecase);

    notifController.add(
      SpNewOutput('abc:0', BigInt.zero),
    );
    await Future.delayed(Duration.zero);

    verify(() => loadUsecase.execute()).called(greaterThanOrEqualTo(1));
    verifyNever(() => scanUsecase.execute());
  });

  test('OutputSpent notification triggers data reload without scan', () async {
    await cubit.load();
    clearInteractions(loadUsecase);

    notifController.add(const SpOutputSpent('abc:0'));
    await Future.delayed(Duration.zero);

    verify(() => loadUsecase.execute()).called(greaterThanOrEqualTo(1));
    verifyNever(() => scanUsecase.execute());
  });

  test('backend status goes online -> offline -> online', () async {
    await cubit.load();
    expect(cubit.state.backendOnline, true);

    notifController.add(const SpBackendOffline());
    await Future.delayed(Duration.zero);
    expect(cubit.state.backendOnline, false);

    // Any backend activity refreshes wallet data, which re-reads a live
    // (online) backend, flipping the status back.
    notifController.add(
      SpElectrumTx(
        kind: SpCoinSource.segwit,
        txid: 'aabbcc',
        amountSat: BigInt.from(1000),
      ),
    );
    await Future.delayed(Duration.zero);
    expect(cubit.state.backendOnline, true);

    verifyNever(() => scanUsecase.execute());
  });
}
