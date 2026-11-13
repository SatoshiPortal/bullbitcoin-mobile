import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart'
    show SpSourceBinding;
import 'package:bb_mobile/features/sp/domain/sp_config.dart';

/// Wire model for the persisted SP backend config. Serialization only; the
/// rules-free counterpart of the [SpBackendConfig] entity.
class SpBackendConfigModel {
  final BitcoinNetwork network;
  final SpSourceBinding? source;
  final String blindbitUrl;
  final String electrumUrl;
  final int fetchConcurrencyFactor;
  final int matchConcurrencyFactor;

  const SpBackendConfigModel({
    required this.network,
    this.source,
    required this.blindbitUrl,
    required this.electrumUrl,
    this.fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    this.matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  });

  factory SpBackendConfigModel.fromJson(Map<String, dynamic> json) =>
      SpBackendConfigModel(
        network: _networkFromJson(json['network'] as String),
        source: _sourceFromJson(json),
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
    if (source != null) ...{
      'schemaVersion': 1,
      'source': {
        'walletId': source!.walletId,
        'secretId': source!.secretId,
        'externalDescriptor': source!.externalDescriptor,
        'internalDescriptor': source!.internalDescriptor,
        'spAddress': source!.spAddress,
      },
    },
    'blindbitUrl': blindbitUrl,
    'electrumUrl': electrumUrl,
    'fetchConcurrencyFactor': fetchConcurrencyFactor,
    'matchConcurrencyFactor': matchConcurrencyFactor,
  };

  static SpSourceBinding? _sourceFromJson(Map<String, dynamic> json) {
    if (!json.containsKey('schemaVersion') && !json.containsKey('source')) {
      return null;
    }
    if (json['schemaVersion'] is! int ||
        json['schemaVersion'] != 1 ||
        json['source'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid SP source version');
    }
    final source = json['source'] as Map<String, dynamic>;
    final binding = SpSourceBinding(
      walletId: source['walletId'] as String,
      secretId: source['secretId'] as String,
      externalDescriptor: source['externalDescriptor'] as String,
      internalDescriptor: source['internalDescriptor'] as String,
      spAddress: source['spAddress'] as String,
    );
    if (!binding.isValid) throw const FormatException('Invalid SP source');
    return binding;
  }

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
