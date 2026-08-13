import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/autoswap/autoswap_watcher.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/execute_autoswap_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchFinished extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class _MockExecuteAutoswap extends Mock implements ExecuteAutoswapUsecase {}

Wallet _wallet({required bool liquid}) => Wallet(
  origin: liquid ? 'liquid' : 'bitcoin',
  network: liquid ? Network.liquidTestnet : Network.bitcoinTestnet,
  isDefault: true,
  xpubFingerprint: 'fingerprint',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'external',
  internalPublicDescriptor: 'internal',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(500000),
);

void main() {
  late StreamController<Wallet> syncs;
  late _MockWatchFinished watchFinished;
  late _MockExecuteAutoswap executeAutoswap;
  late AutoswapWatcher watcher;

  setUp(() {
    syncs = StreamController<Wallet>.broadcast();
    watchFinished = _MockWatchFinished();
    executeAutoswap = _MockExecuteAutoswap();
    when(() => watchFinished.execute()).thenAnswer((_) => syncs.stream);
    watcher = AutoswapWatcher(watchFinished, executeAutoswap)..start();
  });

  tearDown(() async {
    await watcher.dispose();
    await syncs.close();
  });

  test('runs only after a Liquid wallet sync', () async {
    when(
      () => executeAutoswap.execute(),
    ).thenAnswer((_) async => const Ok('order'));

    syncs.add(_wallet(liquid: false));
    await pumpEventQueue();
    verifyNever(() => executeAutoswap.execute());

    syncs.add(_wallet(liquid: true));
    await pumpEventQueue();
    verify(() => executeAutoswap.execute()).called(1);
  });

  test('serializes repeated Liquid sync notifications', () async {
    final execution = Completer<Result<String, AutoswapFailure>>();
    when(() => executeAutoswap.execute()).thenAnswer((_) => execution.future);

    syncs.add(_wallet(liquid: true));
    syncs.add(_wallet(liquid: true));
    await pumpEventQueue();

    verify(() => executeAutoswap.execute()).called(1);
    execution.complete(const Ok('order'));
  });
}
