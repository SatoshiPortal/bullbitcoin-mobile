import 'package:bb_mobile/features/sp/data/models/sp_backend_config_model.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';

/// Maps between the [SpBackendConfig] entity and its wire [SpBackendConfigModel].
abstract final class SpBackendConfigMapper {
  static SpBackendConfig toEntity(SpBackendConfigModel model) =>
      SpBackendConfig(
        network: model.network,
        blindbitUrl: model.blindbitUrl,
        electrumUrl: model.electrumUrl,
        fetchConcurrencyFactor: model.fetchConcurrencyFactor,
        matchConcurrencyFactor: model.matchConcurrencyFactor,
      );

  static SpBackendConfigModel toModel(SpBackendConfig config) =>
      SpBackendConfigModel(
        network: config.network,
        blindbitUrl: config.blindbitUrl,
        electrumUrl: config.electrumUrl,
        fetchConcurrencyFactor: config.fetchConcurrencyFactor,
        matchConcurrencyFactor: config.matchConcurrencyFactor,
      );
}
