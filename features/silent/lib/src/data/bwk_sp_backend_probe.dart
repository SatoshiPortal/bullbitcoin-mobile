import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_backend_defaults.dart';
import 'package:silent/src/domain/entities/sp_backend_kind.dart';
import 'package:silent/src/domain/ports/sp_backend_probe_port.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:rust_bindings/bwk.dart' hide blindbitTip;
import 'package:rust_bindings/bwk.dart' as bwk show blindbitTip;

/// Talks to the SP backends through bwk's standalone free functions, with no
/// account and no session.
class BwkSpBackendProbe implements SpBackendProbePort {
  // bwk connection-test free functions, injectable so `testBackend` can be
  // unit-tested without a real backend.
  final Future<void> Function({required String url}) _testBlindbit;
  final Future<void> Function({required String url}) _testElectrum;
  final Future<int> Function({required String url}) _blindbitTip;

  BwkSpBackendProbe({
    Future<void> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
    Future<int> Function({required String url})? tip,
  }) : _testBlindbit = testBlindbit ?? _probeBlindbit,
       _testElectrum = testElectrum ?? testElectrumUrl,
       _blindbitTip = tip ?? bwk.blindbitTip;

  @override
  Future<Result<void, SilentFailure>> blindbitTip(String url) async {
    try {
      await _blindbitTip(url: url);
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(SilentBackendUnreachable('SP tip probe failed'));
    } on String catch (_) {
      // FRB exposes Rust Result<u32, String> failures as thrown strings.
      return const Err(SilentBackendUnreachable('SP tip probe failed'));
    }
  }

  // A Blindbit server that answers the tip probe may still lack the scan data
  // the wallet needs, so the scan endpoint is the one worth testing. The tip it
  // returns is not read here.
  static Future<void> _probeBlindbit({required String url}) async {
    await testBlindbitScanData(url: url);
  }

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
    } catch (_) {
      // Fixed text: the URL and the foreign error can carry user input and
      // backend detail, and neither belongs in a log or a failure message.
      log.warning('SP backend probe failed ($kind)');
      return Err(SilentBackendUnreachable('SP backend probe failed ($kind)'));
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
