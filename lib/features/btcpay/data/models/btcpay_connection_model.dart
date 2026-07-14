import 'dart:convert';

class BtcpayConnectionModel {
  final String environment;
  final String serverUrl;
  final String storeId;
  final String status;
  final List<String> capabilities;
  final List<String> walletNetworks;
  final String? pairedAt;
  final String updatedAt;
  final String? lastError;

  const BtcpayConnectionModel({
    required this.environment,
    required this.serverUrl,
    required this.storeId,
    required this.status,
    required this.capabilities,
    required this.walletNetworks,
    required this.pairedAt,
    required this.updatedAt,
    this.lastError,
  });

  /// Decodes the persisted JSON string, or returns null when the stored
  /// value is not a structurally valid connection record.
  static BtcpayConnectionModel? tryDecode(String value) {
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final environment = decoded['environment'];
    final serverUrl = decoded['serverUrl'];
    final storeId = decoded['storeId'];
    final status = decoded['status'];
    final pairedAt = decoded['pairedAt'];
    final updatedAt = decoded['updatedAt'];
    final capabilities = decoded['capabilities'];
    final walletNetworks = decoded['walletNetworks'];
    if (environment is! String ||
        serverUrl is! String ||
        storeId is! String ||
        status is! String ||
        updatedAt is! String ||
        capabilities is! List ||
        capabilities.any((value) => value is! String) ||
        walletNetworks is! List ||
        walletNetworks.any((value) => value is! String) ||
        (pairedAt != null && pairedAt is! String) ||
        (decoded['lastError'] != null && decoded['lastError'] is! String)) {
      return null;
    }

    return BtcpayConnectionModel(
      environment: environment,
      serverUrl: serverUrl,
      storeId: storeId,
      status: status,
      capabilities: List<String>.from(capabilities),
      walletNetworks: List<String>.from(walletNetworks),
      pairedAt: pairedAt is String ? pairedAt : null,
      updatedAt: updatedAt,
      lastError: decoded['lastError'] is String
          ? decoded['lastError'] as String
          : null,
    );
  }

  String encode() {
    return jsonEncode({
      'environment': environment,
      'serverUrl': serverUrl,
      'storeId': storeId,
      'status': status,
      'capabilities': capabilities,
      'walletNetworks': walletNetworks,
      'pairedAt': pairedAt,
      'updatedAt': updatedAt,
      'lastError': lastError,
    });
  }
}
