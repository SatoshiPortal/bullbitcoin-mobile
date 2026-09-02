import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_backend_probe_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Resolves the default backend URLs for a network. Regtest defaults come from
/// the running regtest infra (fetched by the probe over FFI, off the UI
/// isolate); the other networks use the static [SpConfig] endpoints and resolve
/// immediately. Keeps the FFI call out of the presentation layer.
class GetSpBackendDefaultsUsecase {
  final SpBackendProbePort _probe;

  GetSpBackendDefaultsUsecase({required this._probe});

  @useResult
  Future<Result<SpBackendDefaults, SpFailure>> execute(BitcoinNetwork network) {
    // Null means the network has no baked-in URLs (regtest), so ask the infra.
    final defaults = SpConfig.staticDefaults(network);
    if (defaults == null) return _probe.fetchRegtestDefaults();
    return Future.value(Ok(defaults));
  }
}
