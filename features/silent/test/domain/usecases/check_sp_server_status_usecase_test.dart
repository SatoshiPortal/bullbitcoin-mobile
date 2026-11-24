import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_backend_config.dart';
import 'package:silent/src/domain/ports/sp_backend_probe_port.dart';
import 'package:silent/src/domain/repositories/sp_backend_config_repository.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/silent_server_status.dart';
import 'package:silent/src/domain/usecases/check_sp_server_status_usecase.dart';
import 'package:silent/src/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';

class _Config extends Mock implements SpBackendConfigRepository {}

class _Setup extends Mock implements CheckSpWalletSetupUsecase {}

class _Gate extends Mock implements GetSpFeatureGateUsecase {}

class _Probe extends Mock implements SpBackendProbePort {}

void main() {
  late _Config config;
  late _Setup setup;
  late _Gate gate;
  late _Probe probe;
  late SpBackendConfig stored;
  late CheckSpServerStatusUsecase usecase;

  setUp(() {
    config = _Config();
    setup = _Setup();
    gate = _Gate();
    probe = _Probe();
    stored = SpBackendConfig(
      network: BitcoinNetwork.mainnet,
      blindbitUrl: 'https://configured.example',
      electrumUrl: 'ssl://example',
    );
    when(config.fetch).thenAnswer((_) async => Ok(stored));
    when(setup.execute).thenAnswer((_) async => const Ok(true));
    when(() => gate.check(network: BitcoinNetwork.mainnet, config: stored))
        .thenAnswer((_) async => const Ok(true));
    when(() => probe.blindbitTip(stored.blindbitUrl))
        .thenAnswer((_) async => const Ok(null));
    usecase = CheckSpServerStatusUsecase(
      config: config,
      setup: setup,
      gate: gate,
      probe: probe,
      timeout: Duration.zero,
    );
  });

  test('probes the configured tip only after admission', () async {
    final result = await usecase.execute(BitcoinNetwork.mainnet);
    expect(
      (result as Ok<SilentServerStatus, SilentFailure>).value,
      SilentServerStatus.online,
    );
    verify(() => gate.check(network: BitcoinNetwork.mainnet, config: stored))
        .called(2);
    verify(() => probe.blindbitTip(stored.blindbitUrl)).called(1);
  });

  test(
    'network mismatch, missing setup and closed gate do not probe',
    () async {
      expect(
        (await usecase.execute(
          BitcoinNetwork.testnet,
        ) as Ok<SilentServerStatus, SilentFailure>).value,
        SilentServerStatus.notApplicable,
      );
      when(setup.execute).thenAnswer((_) async => const Ok(false));
      expect(
        (await usecase.execute(
          BitcoinNetwork.mainnet,
        ) as Ok<SilentServerStatus, SilentFailure>).value,
        SilentServerStatus.notApplicable,
      );
      when(setup.execute).thenAnswer((_) async => const Ok(true));
      when(() => gate.check(network: BitcoinNetwork.mainnet, config: stored))
          .thenAnswer((_) async => const Ok(false));
      expect(
        (await usecase.execute(
          BitcoinNetwork.mainnet,
        ) as Ok<SilentServerStatus, SilentFailure>).value,
        SilentServerStatus.notApplicable,
      );
      verifyNever(() => probe.blindbitTip(any()));
    },
  );

  test('setup or gate errors remain indeterminate and never probe', () async {
    when(setup.execute)
        .thenAnswer((_) async => const Err(SilentUnexpected('read')));
    expect(
      await usecase.execute(BitcoinNetwork.mainnet),
      isA<Err<SilentServerStatus, SilentFailure>>(),
    );
    when(setup.execute).thenAnswer((_) async => const Ok(true));
    when(() => gate.check(network: BitcoinNetwork.mainnet, config: stored))
        .thenAnswer((_) async => const Err(SilentUnexpected('read')));
    expect(
      await usecase.execute(BitcoinNetwork.mainnet),
      isA<Err<SilentServerStatus, SilentFailure>>(),
    );
    verifyNever(() => probe.blindbitTip(any()));
  });

  test('missing or unreadable config never probes', () async {
    when(config.fetch).thenAnswer((_) async => const Ok(null));
    expect(
      (await usecase.execute(
        BitcoinNetwork.mainnet,
      ) as Ok<SilentServerStatus, SilentFailure>).value,
      SilentServerStatus.notApplicable,
    );
    when(config.fetch)
        .thenAnswer((_) async => const Err(SilentUnexpected('read')));
    expect(
      await usecase.execute(BitcoinNetwork.mainnet),
      isA<Err<SilentServerStatus, SilentFailure>>(),
    );
    verifyNever(() => probe.blindbitTip(any()));
  });

  test('a slow tip is offline after admission', () async {
    final pending = Completer<Result<void, SilentFailure>>();
    when(() => probe.blindbitTip(stored.blindbitUrl))
        .thenAnswer((_) => pending.future);
    final result = await usecase.execute(BitcoinNetwork.mainnet);
    expect(
      (result as Ok<SilentServerStatus, SilentFailure>).value,
      SilentServerStatus.offline,
    );
  });
}
