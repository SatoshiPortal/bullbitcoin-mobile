import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server.freezed.dart';

enum ElectrumServerStatus { online, offline, unknown }

@freezed
sealed class ElectrumServer with _$ElectrumServer {
  const factory ElectrumServer({
    required String url,
    required Network network,
    String? socks5,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    @Default(ElectrumServerStatus.unknown) ElectrumServerStatus status,
    @Default(false) bool isActive,
  }) = _ElectrumServer;
  const ElectrumServer._();

  String get displayUrl => _normalizeUrl(url);

  ElectrumServerProvider get electrumServerProvider {
    // Normalize URL by removing protocol prefix for comparison
    final normalizedUrl = _normalizeUrl(url);

    // Check against Bull Bitcoin server URLs
    final bullBitcoinUrls = [
      _normalizeUrl(ApiServiceConstants.bbElectrumUrl),
      _normalizeUrl(ApiServiceConstants.bbElectrumTestUrl),
      _normalizeUrl(ApiServiceConstants.bbLiquidElectrumUrlPath),
      _normalizeUrl(ApiServiceConstants.bbLiquidElectrumTestUrlPath),
    ];

    // Check against Blockstream server URLs
    final blockstreamUrls = [
      _normalizeUrl(ApiServiceConstants.publicElectrumUrl),
      _normalizeUrl(ApiServiceConstants.publicElectrumTestUrl),
      _normalizeUrl(ApiServiceConstants.publicLiquidElectrumUrlPath),
      _normalizeUrl(ApiServiceConstants.publicliquidElectrumTestUrlPath),
    ];

    if (bullBitcoinUrls.any((serverUrl) => normalizedUrl.contains(serverUrl))) {
      return const ElectrumServerProvider.defaultProvider();
    } else if (blockstreamUrls.any(
      (serverUrl) => normalizedUrl.contains(serverUrl),
    )) {
      return const ElectrumServerProvider.defaultProvider(
        defaultServerProvider: DefaultElectrumServerProvider.blockstream,
      );
    } else {
      return const ElectrumServerProvider.customProvider();
    }
  }

  // Helper method to normalize URLs by removing protocol prefixes
  String _normalizeUrl(String serverUrl) {
    final normalized = serverUrl.toLowerCase().trim();
    if (normalized.startsWith('ssl://')) {
      return normalized.substring(6);
    } else if (normalized.startsWith('tcp://')) {
      return normalized.substring(6);
    } else if (normalized.startsWith('http://')) {
      return normalized.substring(7);
    } else if (normalized.startsWith('https://')) {
      return normalized.substring(8);
    }
    return normalized;
  }
}
