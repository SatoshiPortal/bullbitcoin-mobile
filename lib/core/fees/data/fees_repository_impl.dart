import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/data/mappers/mempool_fees_mapper.dart';
import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_tor/tor.dart';

class FeesRepositoryImpl implements FeesRepository {
  final FeesDatasource _feesDatasource;
  final MempoolSettingsRepository _mempoolSettingsRepository;
  final MempoolServerRepository _mempoolServerRepository;
  final SettingsRepository _settingsRepository;
  final Tor _tor;

  const FeesRepositoryImpl({
    required this._feesDatasource,
    required this._mempoolSettingsRepository,
    required this._mempoolServerRepository,
    required this._settingsRepository,
    required this._tor,
  });

  @override
  Future<FeeOptions> getNetworkFees({required Network network}) async {
    if (network.isBitcoin) {
      final baseUrl = await _resolveBitcoinMempoolUrl(
        isTestnet: network.isTestnet,
      );
      final fees = await _fetchBitcoinNetworkFees(baseUrl);
      return MempoolFeesMapper.toFeeOptions(fees);
    }

    // Liquid blocks are typically empty, so the network's minrelayfee
    // (0.1 sat/vByte = 25 sat/kwu) is the only relevant fee tier today.
    // The three presets are kept identical for UI parity with Bitcoin.
    const minRelay = RelativeFee(NetworkFeeRelayPolicy.minRelaySatPerKwu);
    return const FeeOptions(
      fastest: minRelay,
      economic: minRelay,
      slow: minRelay,
      minRelay: minRelay,
    );
  }

  Future<MempoolFeesModel> _fetchBitcoinNetworkFees(String baseUrl) async {
    final settings = await _settingsRepository.fetch();
    if (settings.useTorProxy) {
      return _fetchThroughExternalProxy(
        baseUrl,
        proxyPort: settings.torProxyPort,
      );
    }

    if (_isOnion(baseUrl)) return _fetchThroughEmbeddedTor(baseUrl);

    try {
      return await _feesDatasource.fetchBitcoinNetworkFees(
        baseUrl: baseUrl,
        proxyEndpoint: null,
      );
    } on MempoolFeesException {
      return _fetchThroughEmbeddedTor(baseUrl);
    }
  }

  Future<MempoolFeesModel> _fetchThroughExternalProxy(
    String baseUrl, {
    required int proxyPort,
  }) async {
    final TorProxyEndpoint endpoint;
    try {
      endpoint = TorProxyEndpoint(host: '127.0.0.1', port: proxyPort);
    } on ArgumentError {
      throw MempoolFeesException('Configured fee proxy is unavailable');
    }

    try {
      return switch (await _tor.external.verify(endpoint)) {
        TorReady(:final route) => await _feesDatasource.fetchBitcoinNetworkFees(
          baseUrl: baseUrl,
          proxyEndpoint: route.endpoint,
        ),
        _ => throw MempoolFeesException('Configured fee proxy is unavailable'),
      };
    } on MempoolFeesException {
      rethrow;
    } on Exception {
      throw MempoolFeesException('Configured fee proxy is unavailable');
    }
  }

  Future<MempoolFeesModel> _fetchThroughEmbeddedTor(String baseUrl) async {
    TorSession? session;
    try {
      session = await _tor.embedded.sessions.open();
      return await _feesDatasource.fetchBitcoinNetworkFees(
        baseUrl: baseUrl,
        proxyEndpoint: session.endpoint,
      );
    } on MempoolFeesException {
      rethrow;
    } on Exception {
      throw MempoolFeesException('Tor fee request is unavailable');
    } finally {
      try {
        await session?.close();
      } on Exception {
        // Route cleanup must not replace the fee request result.
      }
    }
  }

  bool _isOnion(String baseUrl) => Uri.parse(
    baseUrl.contains('://') ? baseUrl : 'https://$baseUrl',
  ).host.toLowerCase().endsWith('.onion');

  Future<String> _resolveBitcoinMempoolUrl({required bool isTestnet}) async {
    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: false,
    );
    final settingsResult = await _mempoolSettingsRepository.fetchByNetwork(
      network,
    );
    final settings = switch (settingsResult) {
      Ok(:final value) => value,
      Err() => throw MempoolFeesException('Failed to fetch mempool settings'),
    };
    if (!settings.useForFeeEstimation) {
      return _bbMempoolUrl(isTestnet: isTestnet);
    }

    final customResult = await _mempoolServerRepository.fetchCustomServer(
      network,
    );
    final customServer = switch (customResult) {
      Ok(:final value) => value,
      Err() => throw MempoolFeesException(
        'Failed to fetch custom mempool server',
      ),
    };
    if (customServer != null) return customServer.fullUrl;

    final defaultResult = await _mempoolServerRepository.fetchDefaultServer(
      network,
    );
    final defaultServer = switch (defaultResult) {
      Ok(:final value) => value,
      Err() => throw MempoolFeesException(
        'Failed to fetch default mempool server',
      ),
    };
    return defaultServer.fullUrl;
  }

  String _bbMempoolUrl({required bool isTestnet}) => isTestnet
      ? 'https://${ApiServiceConstants.testnetMempoolUrlPath}'
      : 'https://${ApiServiceConstants.bbMempoolUrlPath}';
}
