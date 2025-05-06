import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server_model.freezed.dart';
part 'electrum_server_model.g.dart';

@freezed
sealed class ElectrumServerModel with _$ElectrumServerModel {
  const factory ElectrumServerModel({
    required String url,
    required bool isTestnet,
    required bool isLiquid,
    required ElectrumServerProvider electrumServerProvider,
    String? socks5,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    @Default(ElectrumServerStatus.unknown) ElectrumServerStatus status,
    @Default(false) bool isActive,
    @Default(1) int priority,
  }) = _ElectrumServerModel;
  factory ElectrumServerModel.customServer({
    required String url,
    required bool isTestnet,
    required bool isLiquid,
    String? socks5,
    int stopGap = 20,
    int timeout = 5,
    int retry = 5,
    bool isActive = true,
    bool validateDomain = true,
  }) => ElectrumServerModel(
    url: url,
    isTestnet: isTestnet,
    isLiquid: isLiquid,
    electrumServerProvider: const ElectrumServerProvider.customProvider(),
    socks5: socks5,
    stopGap: stopGap,
    timeout: timeout,
    retry: retry,
    isActive: isActive,
    validateDomain: validateDomain,
    priority: 0,
  );
  factory ElectrumServerModel.defaultServer({
    required bool isTestnet,
    required bool isLiquid,
    required DefaultElectrumServerProvider defaultElectrumServerProvider,
    int stopGap = 20,
    int timeout = 5,
    int retry = 5,
    bool validateDomain = true,
  }) => ElectrumServerModel(
    url: switch (defaultElectrumServerProvider) {
      DefaultElectrumServerProvider.bullBitcoin => switch ((
        isTestnet,
        isLiquid,
      )) {
        (false, false) => ApiServiceConstants.bbElectrumUrl,
        (true, false) => ApiServiceConstants.bbElectrumTestUrl,
        (false, true) => ApiServiceConstants.bbLiquidElectrumUrlPath,
        (true, true) => ApiServiceConstants.bbLiquidElectrumTestUrlPath,
      },
      DefaultElectrumServerProvider.blockstream => switch ((
        isTestnet,
        isLiquid,
      )) {
        (false, false) => ApiServiceConstants.publicElectrumUrl,
        (true, false) => ApiServiceConstants.publicElectrumTestUrl,
        (false, true) => ApiServiceConstants.publicLiquidElectrumUrlPath,
        (true, true) => ApiServiceConstants.publicliquidElectrumTestUrlPath,
      },
    },
    isTestnet: isTestnet,
    isLiquid: isLiquid,
    electrumServerProvider: ElectrumServerProvider.defaultProvider(
      defaultServerProvider: defaultElectrumServerProvider,
    ),
    stopGap: stopGap,
    timeout: timeout,
    retry: retry,
    validateDomain: validateDomain,
    priority: switch (defaultElectrumServerProvider) {
      DefaultElectrumServerProvider.bullBitcoin => 1,
      DefaultElectrumServerProvider.blockstream => 2,
    },
  );

  const ElectrumServerModel._();

  /// Get the SOCKS5 proxy for this server (only available for custom servers)
  String? get serverSocks5 {
    if (electrumServerProvider is CustomElectrumServerProvider) {
      return socks5;
    }
    return null;
  }

  /// Flag indicating if this is a custom active server
  bool get isCustomServerActive {
    return electrumServerProvider is CustomElectrumServerProvider && isActive;
  }

  factory ElectrumServerModel.fromJson(Map<String, dynamic> json) =>
      _$ElectrumServerModelFromJson(json);

  ElectrumServer toEntity() {
    final network = Network.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );

    if (electrumServerProvider is DefaultServerProvider) {
      final defaultElectrumServerProvider =
          electrumServerProvider as DefaultServerProvider;
      final providerType = defaultElectrumServerProvider.defaultServerProvider;
      return ElectrumServer.defaultServer(
        network: network,
        provider: providerType,
        stopGap: stopGap,
        timeout: timeout,
        retry: retry,
        validateDomain: validateDomain,
        priority: priority,
      );
    } else {
      return ElectrumServer.customServer(
        url: url,
        network: network,
        socks5: socks5,
        stopGap: stopGap,
        timeout: timeout,
        retry: retry,
        validateDomain: validateDomain,
        isActive: isActive,
      );
    }
  }

  factory ElectrumServerModel.fromEntity(ElectrumServer entity) {
    // Check server provider type
    final electrumServerProvider = entity.electrumServerProvider;

    if (electrumServerProvider is DefaultServerProvider) {
      return ElectrumServerModel.defaultServer(
        retry: entity.retry,
        timeout: entity.timeout,
        defaultElectrumServerProvider:
            electrumServerProvider.defaultServerProvider,
        stopGap: entity.stopGap,
        validateDomain: entity.validateDomain,
        isTestnet: entity.network.isTestnet,
        isLiquid: entity.network.isLiquid,
      );
    } else {
      return ElectrumServerModel.customServer(
        url: entity.url,
        socks5: entity.socks5,
        stopGap: entity.stopGap,
        timeout: entity.timeout,
        retry: entity.retry,
        validateDomain: entity.validateDomain,
        isTestnet: entity.network.isTestnet,
        isLiquid: entity.network.isLiquid,
        isActive: entity.isActive,
      );
    }
  }

  factory ElectrumServerModel.fromSqlite(ElectrumServerRow row) {
    final network = Network.fromEnvironment(
      isTestnet: row.isTestnet,
      isLiquid: row.isLiquid,
    );

    final isBullBitcoin = switch (network) {
      Network.bitcoinMainnet => row.url == ApiServiceConstants.bbElectrumUrl,
      Network.bitcoinTestnet =>
        row.url == ApiServiceConstants.bbElectrumTestUrl,
      Network.liquidMainnet =>
        row.url == ApiServiceConstants.bbLiquidElectrumUrlPath,
      Network.liquidTestnet =>
        row.url == ApiServiceConstants.bbLiquidElectrumTestUrlPath,
    };

    if (isBullBitcoin) {
      return ElectrumServerModel.defaultServer(
        defaultElectrumServerProvider:
            DefaultElectrumServerProvider.bullBitcoin,
        retry: row.retry,
        timeout: row.timeout,
        stopGap: row.stopGap,
        validateDomain: row.validateDomain,
        isTestnet: row.isTestnet,
        isLiquid: row.isLiquid,
      );
    }

    final isBlockstream = switch (network) {
      Network.bitcoinMainnet =>
        row.url == ApiServiceConstants.publicElectrumUrl,
      Network.bitcoinTestnet =>
        row.url == ApiServiceConstants.publicElectrumTestUrl,
      Network.liquidMainnet =>
        row.url == ApiServiceConstants.publicLiquidElectrumUrlPath,
      Network.liquidTestnet =>
        row.url == ApiServiceConstants.publicliquidElectrumTestUrlPath,
    };

    if (isBlockstream) {
      return ElectrumServerModel.defaultServer(
        defaultElectrumServerProvider:
            DefaultElectrumServerProvider.blockstream,
        retry: row.retry,
        timeout: row.timeout,
        stopGap: row.stopGap,
        validateDomain: row.validateDomain,
        isTestnet: row.isTestnet,
        isLiquid: row.isLiquid,
      );
    }

    return ElectrumServerModel.customServer(
      url: row.url,
      socks5: row.socks5,
      retry: row.retry,
      timeout: row.timeout,
      stopGap: row.stopGap,
      validateDomain: row.validateDomain,
      isTestnet: row.isTestnet,
      isLiquid: row.isLiquid,
    );
  }

  ElectrumServerRow toSqlite() {
    return ElectrumServerRow(
      url: url,
      socks5: socks5,
      retry: retry,
      timeout: timeout,
      stopGap: stopGap,
      validateDomain: validateDomain,
      isTestnet: isTestnet,
      isLiquid: isLiquid,
      priority: priority,
      isActive: isActive,
    );
  }
}
