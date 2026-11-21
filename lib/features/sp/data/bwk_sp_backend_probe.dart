import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_backend_probe_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
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
  }) : _testBlindbit =
           testBlindbit ??
           (({required url}) =>
               testBlindbitUrl(url: url, requireScanData: true)),
       _testElectrum = testElectrum ?? testElectrumUrl;

  @override
  Future<Result<void, SpFailure>> testBackend(
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
    } catch (_) {
      log.warning('SP backend probe failed ($kind)');
      return Err(SpBackendUnreachable('SP backend probe failed ($kind)'));
    }
  }

  @override
  Future<Result<SpBackendDefaults, SpFailure>> fetchRegtestDefaults() async {
    final defaults = await getRegtestDefaults();
    if (!defaults.isOk) {
      return Err(SpBackendUnreachable(defaults.error));
    }
    return Ok(
      SpBackendDefaults(
        blindbitUrl: defaults.blindbitUrl,
        electrumUrl: defaults.electrumUrl,
      ),
    );
  }
}
