import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';

/// Resolves the default backend URLs for a network. Regtest defaults come from
/// the running regtest infra (fetched by the repository via FFI); the other
/// networks use the static [SpConfig] endpoints. Keeps the FFI call out of the
/// presentation layer.
class GetSpBackendDefaultsUsecase {
  final SpBackendConfigRepository _configRepository;

  GetSpBackendDefaultsUsecase({required this._configRepository});

  SpBackendDefaults execute(SpNetwork network) {
    if (network == SpNetwork.regtest) {
      return _configRepository.fetchRegtestDefaults();
    }
    return SpBackendDefaults.ok(
      blindbitUrl: SpConfig.defaultBlindbitUrl[network] ?? '',
      electrumUrl: SpConfig.defaultElectrumUrl[network] ?? '',
    );
  }
}
