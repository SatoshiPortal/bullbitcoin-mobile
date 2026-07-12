import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Resolves the default backend URLs for a network. Regtest defaults come from
/// the running regtest infra (fetched by the repository over FFI, off the UI
/// isolate); the other networks use the static [SpConfig] endpoints and resolve
/// immediately. Keeps the FFI call out of the presentation layer.
class GetSpBackendDefaultsUsecase {
  final SpBackendConfigRepository _configRepository;

  GetSpBackendDefaultsUsecase({required this._configRepository});

  @useResult
  Future<Result<SpBackendDefaults, SpFailure>> execute(SpNetwork network) {
    if (network == SpNetwork.regtest) {
      return _configRepository.fetchRegtestDefaults();
    }
    return Future.value(
      Ok(
        SpBackendDefaults(
          blindbitUrl: SpConfig.defaultBlindbitUrl[network] ?? '',
          electrumUrl: SpConfig.defaultElectrumUrl[network] ?? '',
        ),
      ),
    );
  }
}
