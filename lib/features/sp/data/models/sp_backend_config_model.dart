import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';

/// Wire model for the persisted SP backend config. Serialization only; the
/// rules-free counterpart of the [SpBackendConfig] entity.
class SpBackendConfigModel {
  final SpNetwork network;
  final String blindbitUrl;
  final String electrumUrl;
  final int fetchConcurrencyFactor;
  final int matchConcurrencyFactor;

  const SpBackendConfigModel({
    required this.network,
    required this.blindbitUrl,
    required this.electrumUrl,
    this.fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    this.matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  });

  factory SpBackendConfigModel.fromJson(Map<String, dynamic> json) =>
      SpBackendConfigModel(
        network: SpNetwork.values.byName(json['network'] as String),
        blindbitUrl: json['blindbitUrl'] as String,
        electrumUrl: json['electrumUrl'] as String,
        fetchConcurrencyFactor:
            json['fetchConcurrencyFactor'] as int? ??
            SpConfig.defaultFetchConcurrencyFactor,
        matchConcurrencyFactor:
            json['matchConcurrencyFactor'] as int? ??
            SpConfig.defaultMatchConcurrencyFactor,
      );

  Map<String, dynamic> toJson() => {
    'network': network.name,
    'blindbitUrl': blindbitUrl,
    'electrumUrl': electrumUrl,
    'fetchConcurrencyFactor': fetchConcurrencyFactor,
    'matchConcurrencyFactor': matchConcurrencyFactor,
  };
}
