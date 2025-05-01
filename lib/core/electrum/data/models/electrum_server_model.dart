import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server_model.freezed.dart';
part 'electrum_server_model.g.dart';

@freezed
sealed class ElectrumServerModel with _$ElectrumServerModel {
  factory ElectrumServerModel.bullBitcoin({
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    required bool isTestnet,
    required bool isLiquid,
    @Default(1) int priority,
  }) = BullBitcoinElectrumServerModel;

  factory ElectrumServerModel.blockstream({
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    required bool isTestnet,
    required bool isLiquid,
    @Default(2) int priority,
  }) = BlockstreamElectrumServerModel;

  factory ElectrumServerModel.custom({
    required String url,
    String? socks5,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    required bool isTestnet,
    required bool isLiquid,
    @Default(0) int priority,
  }) = CustomElectrumServerModel;

  const ElectrumServerModel._();

  /// Get the URL for this server
  String get url {
    final network = Network.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );

    return switch (this) {
      CustomElectrumServerModel() => (this as CustomElectrumServerModel).url,
      BullBitcoinElectrumServerModel() => switch (network) {
        Network.bitcoinMainnet => ApiServiceConstants.bbElectrumUrl,
        Network.bitcoinTestnet => ApiServiceConstants.bbElectrumTestUrl,
        Network.liquidMainnet => ApiServiceConstants.bbLiquidElectrumUrlPath,
        Network.liquidTestnet =>
          ApiServiceConstants.bbLiquidElectrumTestUrlPath,
      },
      BlockstreamElectrumServerModel() => switch (network) {
        Network.bitcoinMainnet => ApiServiceConstants.publicElectrumUrl,
        Network.bitcoinTestnet => ApiServiceConstants.publicElectrumTestUrl,
        Network.liquidMainnet =>
          ApiServiceConstants.publicLiquidElectrumUrlPath,
        Network.liquidTestnet =>
          ApiServiceConstants.publicliquidElectrumTestUrlPath,
      },
    };
  }

  /// Get the SOCKS5 proxy for this server (only available for custom servers)
  String? get socks5 =>
      this is CustomElectrumServerModel
          ? (this as CustomElectrumServerModel).socks5
          : null;

  /// Flag indicating if this is a custom active server
  bool get isActive => switch (this) {
    CustomElectrumServerModel(:final isActive) => isActive,
    _ => false,
  };

  factory ElectrumServerModel.fromJson(Map<String, dynamic> json) =>
      _$ElectrumServerModelFromJson(json);

  factory ElectrumServerModel.fromEntity(ElectrumServer entity) {
    // Check server provider type
    final electrumServerProvider = entity.electrumServerProvider;

    if (electrumServerProvider is DefaultServerProvider) {
      final provider = electrumServerProvider.defaultServerProvider;

      switch (provider) {
        case DefaultElectrumServerProvider.bullBitcoin:
          return BullBitcoinElectrumServerModel(
            retry: entity.retry,
            timeout: entity.timeout,
            stopGap: entity.stopGap,
            validateDomain: entity.validateDomain,
            isTestnet: entity.network.isTestnet,
            isLiquid: entity.network.isLiquid,
            priority: entity.priority,
          );
        case DefaultElectrumServerProvider.blockstream:
          return BlockstreamElectrumServerModel(
            retry: entity.retry,
            timeout: entity.timeout,
            stopGap: entity.stopGap,
            validateDomain: entity.validateDomain,
            isTestnet: entity.network.isTestnet,
            isLiquid: entity.network.isLiquid,
            priority: entity.priority,
          );
      }
    } else if (electrumServerProvider is CustomElectrumServerProvider) {
      return CustomElectrumServerModel(
        url: entity.url,
        socks5: entity.socks5,
        stopGap: entity.stopGap,
        timeout: entity.timeout,
        retry: entity.retry,
        validateDomain: entity.validateDomain,
        isTestnet: entity.network.isTestnet,
        isLiquid: entity.network.isLiquid,
        priority: entity.priority,
      );
    }

    throw ArgumentError(
      'Unsupported ElectrumServerProvider type: ${electrumServerProvider.runtimeType}',
    );
  }

  ElectrumServer toEntity() {
    final network = Network.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );

    switch (this) {
      case CustomElectrumServerModel():
        final custom = this as CustomElectrumServerModel;
        return ElectrumServer.customServer(
          url: custom.url,
          network: network,
          socks5: custom.socks5,
          stopGap: custom.stopGap,
          timeout: custom.timeout,
          retry: custom.retry,
          validateDomain: custom.validateDomain,
          isActive: custom.isActive,
        );
      case BullBitcoinElectrumServerModel():
        return ElectrumServer.defaultServer(
          network: network,
          provider: DefaultElectrumServerProvider.bullBitcoin,
          stopGap: stopGap,
          timeout: timeout,
          retry: retry,
          validateDomain: validateDomain,
          priority: priority,
        );
      case BlockstreamElectrumServerModel():
        return ElectrumServer(
          url: url,
          network: network,
          electrumServerProvider: const ElectrumServerProvider.defaultProvider(
            defaultServerProvider: DefaultElectrumServerProvider.blockstream,
          ),
          stopGap: stopGap,
          timeout: timeout,
          retry: retry,
          validateDomain: validateDomain,
          priority: priority,
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
      return BullBitcoinElectrumServerModel(
        retry: row.retry,
        timeout: row.timeout,
        stopGap: row.stopGap,
        validateDomain: row.validateDomain,
        isTestnet: row.isTestnet,
        isLiquid: row.isLiquid,
        priority: row.priority,
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
      return BlockstreamElectrumServerModel(
        retry: row.retry,
        timeout: row.timeout,
        stopGap: row.stopGap,
        validateDomain: row.validateDomain,
        isTestnet: row.isTestnet,
        isLiquid: row.isLiquid,
        priority: row.priority,
      );
    }

    return CustomElectrumServerModel(
      url: row.url,
      socks5: row.socks5,
      retry: row.retry,
      timeout: row.timeout,
      stopGap: row.stopGap,
      validateDomain: row.validateDomain,
      isTestnet: row.isTestnet,
      isLiquid: row.isLiquid,
      priority: row.priority,
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
