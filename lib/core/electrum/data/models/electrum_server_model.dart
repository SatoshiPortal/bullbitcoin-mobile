import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
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
    @Default(false) bool isActive,
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
            ApiServiceConstants.publicLiquidElectrumUrlPath,
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
  String? get socks5 => this is CustomElectrumServerModel
      ? (this as CustomElectrumServerModel).socks5
      : null;

  /// Flag indicating if this is a custom active server
  bool get isActive =>
      this is CustomElectrumServerModel &&
      (this as CustomElectrumServerModel).isActive;

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
        isActive: entity.isActive,
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
}
