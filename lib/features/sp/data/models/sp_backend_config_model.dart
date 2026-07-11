import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';

/// Wire model for the persisted SP backend config. Serialization only; the
/// rules-free counterpart of the [SpBackendConfig] entity.
class SpBackendConfigModel {
  const SpBackendConfigModel({
    required this.network,
    required this.blindbitUrl,
    required this.electrumUrl,
  });

  final SpNetwork network;
  final String blindbitUrl;
  final String electrumUrl;

  Map<String, dynamic> toJson() => {
    'network': network.name,
    'blindbitUrl': blindbitUrl,
    'electrumUrl': electrumUrl,
  };

  factory SpBackendConfigModel.fromJson(Map<String, dynamic> json) =>
      SpBackendConfigModel(
        network: SpNetwork.values.byName(json['network'] as String),
        blindbitUrl: json['blindbitUrl'] as String,
        electrumUrl: json['electrumUrl'] as String,
      );
}
