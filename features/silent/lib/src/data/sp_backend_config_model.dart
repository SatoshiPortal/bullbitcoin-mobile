import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/sp_config.dart';

/// Wire model for the persisted SP backend config. Serialization only; the
/// rules-free counterpart of the [SpBackendConfig] entity.
class SpBackendConfigModel {
  static const _endpointVersionKey = 'defaultEndpointsVersion';
  static const _legacyBlindbitUrl = 'https://blindbit.pythcoiner.dev';
  static const _legacyElectrumUrl = 'ssl://electrum.pythcoiner.dev:50002';

  final BitcoinNetwork network;
  final String blindbitUrl;
  final String electrumUrl;
  final int fetchConcurrencyFactor;
  final int matchConcurrencyFactor;
  final int minScanAmountSat;

  const SpBackendConfigModel({
    required this.network,
    required this.blindbitUrl,
    required this.electrumUrl,
    this.fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    this.matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
    this.minScanAmountSat = SpConfig.defaultMinScanAmountSat,
  });

  factory SpBackendConfigModel.fromJson(Map<String, dynamic> json) {
    final network = _networkFromJson(json['network'] as String);
    final blindbit = json['blindbitUrl'] as String;
    final electrum = json['electrumUrl'] as String;
    // Legacy records did not distinguish defaults from custom endpoints.
    // Only replace exact matches; versioned records preserve explicit choices.
    final defaults =
        !json.containsKey(_endpointVersionKey) &&
            network == BitcoinNetwork.mainnet
        ? SpConfig.staticDefaults(network)
        : null;
    return SpBackendConfigModel(
      network: network,
      blindbitUrl: blindbit == _legacyBlindbitUrl
          ? defaults?.blindbitUrl ?? blindbit
          : blindbit,
      electrumUrl: electrum == _legacyElectrumUrl
          ? defaults?.electrumUrl ?? electrum
          : electrum,
      fetchConcurrencyFactor:
          json['fetchConcurrencyFactor'] as int? ??
          SpConfig.defaultFetchConcurrencyFactor,
      matchConcurrencyFactor:
          json['matchConcurrencyFactor'] as int? ??
          SpConfig.defaultMatchConcurrencyFactor,
      minScanAmountSat:
          json['minScanAmountSat'] as int? ?? SpConfig.legacyMinScanAmountSat,
    );
  }

  Map<String, dynamic> toJson() => {
    'network': network.name,
    'blindbitUrl': blindbitUrl,
    'electrumUrl': electrumUrl,
    'fetchConcurrencyFactor': fetchConcurrencyFactor,
    'matchConcurrencyFactor': matchConcurrencyFactor,
    'minScanAmountSat': minScanAmountSat,
    _endpointVersionKey: 1,
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
