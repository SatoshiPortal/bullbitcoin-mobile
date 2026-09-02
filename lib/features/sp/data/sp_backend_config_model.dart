import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';

/// Wire model for the persisted SP backend config. Serialization only; the
/// rules-free counterpart of the [SpBackendConfig] entity.
class SpBackendConfigModel {
  final BitcoinNetwork network;
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
        network: _networkFromJson(json['network'] as String),
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

  /// Reads the persisted network name.
  ///
  /// Installs made before the switch to [BitcoinNetwork] stored the mainnet
  /// value as `bitcoin`; accept it so an existing wallet keeps loading. Every
  /// other name matches, and an unknown one still throws so the repository can
  /// map it to a typed failure.
  static BitcoinNetwork _networkFromJson(String name) => name == 'bitcoin'
      ? BitcoinNetwork.mainnet
      : BitcoinNetwork.fromName(name);
}
