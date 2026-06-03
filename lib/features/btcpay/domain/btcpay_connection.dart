import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';

enum BtcpayConnectionStatus { paired, uncertain }

class BtcpayConnection {
  final Environment environment;
  final String serverUrl;
  final String storeId;
  final List<SamRockSetupCapability> capabilities;
  final List<BtcpayWalletNetwork> walletNetworks;
  final Map<BtcpayWalletNetwork, String> walletIds;
  final BtcpayConnectionStatus status;
  final DateTime? pairedAt;
  final DateTime updatedAt;
  final String? lastError;

  const BtcpayConnection._({
    required this.environment,
    required this.serverUrl,
    required this.storeId,
    required this.capabilities,
    required this.walletNetworks,
    this.walletIds = const {},
    required this.status,
    required this.pairedAt,
    required this.updatedAt,
    this.lastError,
  });

  factory BtcpayConnection.fromPairing({
    required Environment environment,
    required SamRockPairingRequest request,
    required List<BtcpayWalletNetwork> walletNetworks,
    required Map<BtcpayWalletNetwork, String> walletIds,
    required BtcpayConnectionStatus status,
    required DateTime updatedAt,
    DateTime? pairedAt,
    String? lastError,
  }) {
    final connection = BtcpayConnection.tryCreate(
      environment: environment,
      serverUrl: btcpayServerUrlFor(request),
      storeId: request.storeId,
      capabilities: request.setup.toList()
        ..sort((a, b) => a.value.compareTo(b.value)),
      walletNetworks: walletNetworks,
      walletIds: walletIds,
      status: status,
      pairedAt: pairedAt,
      updatedAt: updatedAt,
      lastError: lastError,
    );
    if (connection == null) {
      throw ArgumentError('Invalid BTCPay pairing connection');
    }
    return connection;
  }

  bool get isPaired => status == BtcpayConnectionStatus.paired;
  bool get isUncertain => status == BtcpayConnectionStatus.uncertain;
  bool get supportsBitcoinChain =>
      capabilities.contains(SamRockSetupCapability.bitcoinChain);
  bool get supportsLiquidChain =>
      capabilities.contains(SamRockSetupCapability.liquidChain);
  bool get supportsLightning =>
      capabilities.contains(SamRockSetupCapability.bitcoinLightning);

  static BtcpayConnection? tryCreate({
    required Environment environment,
    required String serverUrl,
    required String storeId,
    required List<SamRockSetupCapability> capabilities,
    required List<BtcpayWalletNetwork> walletNetworks,
    required BtcpayConnectionStatus status,
    required DateTime? pairedAt,
    required DateTime updatedAt,
    String? lastError,
  }) {
    if (!_isValidServerUrl(serverUrl) ||
        storeId.isEmpty ||
        storeId != storeId.trim() ||
        capabilities.isEmpty ||
        capabilities.toSet().length != capabilities.length ||
        walletNetworks.isEmpty ||
        walletNetworks.toSet().length != walletNetworks.length ||
        !updatedAt.isUtc ||
        (pairedAt != null && !pairedAt.isUtc) ||
        (pairedAt != null && pairedAt.isAfter(updatedAt)) ||
        (status == BtcpayConnectionStatus.paired && pairedAt == null) ||
        (lastError != null &&
            (lastError.isEmpty || lastError != lastError.trim()))) {
      return null;
    }

    final needsBitcoin = capabilities.contains(
      SamRockSetupCapability.bitcoinChain,
    );
    final needsLiquid = capabilities.contains(
      SamRockSetupCapability.liquidChain,
    );
    final needsLightning = capabilities.contains(
      SamRockSetupCapability.bitcoinLightning,
    );
    if ((needsBitcoin &&
            !walletNetworks.contains(BtcpayWalletNetwork.bitcoin)) ||
        ((needsLiquid || needsLightning) &&
            !walletNetworks.contains(BtcpayWalletNetwork.liquid))) {
      return null;
    }

    return BtcpayConnection._(
      environment: environment,
      serverUrl: serverUrl,
      storeId: storeId,
      capabilities: List.unmodifiable(capabilities),
      walletNetworks: List.unmodifiable(walletNetworks),
      status: status,
      pairedAt: pairedAt,
      updatedAt: updatedAt,
      lastError: lastError,
    );
  }

  BtcpayConnection copyWith({
    BtcpayConnectionStatus? status,
    DateTime? pairedAt,
    DateTime? updatedAt,
    String? lastError,
    bool clearLastError = false,
  }) {
    final connection = BtcpayConnection.tryCreate(
      environment: environment,
      serverUrl: serverUrl,
      storeId: storeId,
      capabilities: capabilities,
      walletNetworks: walletNetworks,
      walletIds: walletIds,
      status: status ?? this.status,
      pairedAt: pairedAt ?? this.pairedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
    if (connection == null) {
      throw StateError('Invalid BTCPay connection state transition');
    }
    return connection;
  }

  static bool _isValidServerUrl(String value) {
    if (value.isEmpty || value != value.trim()) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (uri.path.isEmpty || uri.path == '/') &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}

String btcpayServerUrlFor(SamRockPairingRequest request) {
  final uri = request.protocolUri;
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://$host$port';
}
