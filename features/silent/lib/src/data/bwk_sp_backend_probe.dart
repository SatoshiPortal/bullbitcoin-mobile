import 'dart:developer' as developer;

import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_backend_defaults.dart';
import 'package:silent/src/domain/entities/sp_backend_kind.dart';
import 'package:silent/src/domain/ports/sp_backend_probe_port.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:rust_bindings/bwk.dart';

/// Talks to the SP backends through bwk's standalone free functions, with no
/// account and no session.
class BwkSpBackendProbe implements SpBackendProbePort {
  // bwk connection-test free functions, injectable so `testBackend` can be
  // unit-tested without a real backend.
  final Future<void> Function({required String url}) _testBlindbit;
  final Future<void> Function({required String url}) _testElectrum;

  BwkSpBackendProbe({
    Future<void> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
  }) : _testBlindbit = testBlindbit ?? testBlindbitUrl,
       _testElectrum = testElectrum ?? testElectrumUrl;

  @override
  Future<Result<void, SilentFailure>> testBackend(
    SpBackendKind kind,
    String url,
  ) async {
    try {
      switch (kind) {
        case SpBackendKind.blindbit:
          await _testBlindbit(url: url);
        case SpBackendKind.electrum:
          await _testElectrum(url: url);
      }
      return const Ok(null);
    } catch (e) {
      developer.log('SP backend test failed ($kind, $url): $e', name: 'SP');
      log.warning('SP backend test failed ($kind, $url)', error: e);
      return Err(SilentBackendUnreachable('SP backend test failed ($url): $e'));
    }
  }

  @override
  Future<Result<SpBackendDefaults, SilentFailure>>
  fetchRegtestDefaults() async {
    final defaults = await getRegtestDefaults();
    if (!defaults.isOk) {
      return Err(SilentBackendUnreachable(defaults.error));
    }
    return Ok(
      SpBackendDefaults(
        blindbitUrl: defaults.blindbitUrl,
        electrumUrl: defaults.electrumUrl,
      ),
    );
  }
}
