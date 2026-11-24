import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/ports/sp_backend_probe_port.dart';
import 'package:silent/src/domain/repositories/sp_backend_config_repository.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/silent_server_status.dart';
import 'package:silent/src/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';

class CheckSpServerStatusUsecase {
  final SpBackendConfigRepository _config;
  final CheckSpWalletSetupUsecase _setup;
  final GetSpFeatureGateUsecase _gate;
  final SpBackendProbePort _probe;
  final Duration _timeout;

  CheckSpServerStatusUsecase({
    required this._config,
    required this._setup,
    required this._gate,
    required this._probe,
    this._timeout = const Duration(seconds: 20),
  });

  Future<Result<SilentServerStatus, SilentFailure>> execute(
    BitcoinNetwork network,
  ) async {
    final configResult = await _config.fetch();
    if (configResult case Err(:final failure)) return Err(failure);
    final config = switch (configResult) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (config == null || config.network != network) {
      return const Ok(SilentServerStatus.notApplicable);
    }
    final setup = await _setup.execute();
    if (setup case Err(:final failure)) return Err(failure);
    if (setup case Ok(value: false)) {
      return const Ok(SilentServerStatus.notApplicable);
    }
    final gate = await _gate.check(network: network, config: config);
    if (gate case Err(:final failure)) return Err(failure);
    if (gate case Ok(value: false)) {
      return const Ok(SilentServerStatus.notApplicable);
    }
    final status = await _readStatus(config.blindbitUrl);
    // Do not publish a result for a configuration or setup revoked while the
    // request was in flight. These reads are not part of the network timeout.
    final currentSetup = await _setup.execute();
    if (currentSetup case Err(:final failure)) return Err(failure);
    if (currentSetup case Ok(value: false)) {
      return const Ok(SilentServerStatus.notApplicable);
    }
    final currentGate = await _gate.check(network: network, config: config);
    if (currentGate case Err(:final failure)) return Err(failure);
    if (currentGate case Ok(value: false)) {
      return const Ok(SilentServerStatus.notApplicable);
    }
    return Ok(status);
  }

  Future<SilentServerStatus> _readStatus(String url) async {
    try {
      return switch (await _probe.blindbitTip(url).timeout(_timeout)) {
        Ok() => SilentServerStatus.online,
        Err() => SilentServerStatus.offline,
      };
    } on TimeoutException {
      return SilentServerStatus.offline;
    }
  }
}
