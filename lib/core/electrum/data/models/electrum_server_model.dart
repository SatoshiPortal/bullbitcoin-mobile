import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server_model.freezed.dart';
part 'electrum_server_model.g.dart';

@freezed
sealed class ElectrumServerModel with _$ElectrumServerModel {
  factory ElectrumServerModel.custom({
    required String url,
    String? socks5,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    required bool isTestnet,
    required bool isLiquid,
  }) = CustomElectrumServerModel;
  factory ElectrumServerModel.bullBitcoin({
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    required bool isTestnet,
    required bool isLiquid,
  }) = BullBitcoinElectrumServerModel;
  factory ElectrumServerModel.blockstream({
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    required bool isTestnet,
    required bool isLiquid,
  }) = BlockstreamElectrumServerModel;
  const ElectrumServerModel._();

  factory ElectrumServerModel.fromJson(Map<String, dynamic> json) =>
      _$ElectrumServerModelFromJson(json);

  factory ElectrumServerModel.fromEntity(ElectrumServer entity) {
    switch (entity.provider) {
      case ElectrumServerProvider.bullBitcoin:
        return BullBitcoinElectrumServerModel(
          retry: entity.retry,
          timeout: entity.timeout,
          stopGap: entity.stopGap,
          validateDomain: entity.validateDomain,
          isTestnet: entity.network.isTestnet,
          isLiquid: entity.network.isLiquid,
        );
      case ElectrumServerProvider.blockstream:
        return BlockstreamElectrumServerModel(
          retry: entity.retry,
          timeout: entity.timeout,
          stopGap: entity.stopGap,
          validateDomain: entity.validateDomain,
          isTestnet: entity.network.isTestnet,
          isLiquid: entity.network.isLiquid,
        );
      case ElectrumServerProvider.custom:
        return CustomElectrumServerModel(
          url: entity.url,
          socks5: entity.socks5,
          retry: entity.retry,
          timeout: entity.timeout,
          stopGap: entity.stopGap,
          validateDomain: entity.validateDomain,
          isTestnet: entity.network.isTestnet,
          isLiquid: entity.network.isLiquid,
        );
    }
  }

  ElectrumServer toEntity() {
    final network = Network.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );

    final electrumServer = ElectrumServer(
      provider: provider,
      url: url,
      network: network,
      stopGap: stopGap,
      timeout: timeout,
      retry: retry,
      validateDomain: validateDomain,
    );

    return electrumServer;
  }

  String get url {
    final network = Network.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );
    return switch (this) {
      BullBitcoinElectrumServerModel _ => switch (network) {
          Network.bitcoinMainnet => ApiServiceConstants.bbElectrumUrl,
          Network.bitcoinTestnet => ApiServiceConstants.bbElectrumTestUrl,
          Network.liquidMainnet => ApiServiceConstants.bbLiquidElectrumUrlPath,
          Network.liquidTestnet =>
            ApiServiceConstants.publicLiquidElectrumUrlPath,
        },
      BlockstreamElectrumServerModel _ => switch (network) {
          Network.bitcoinMainnet => ApiServiceConstants.publicElectrumUrl,
          Network.bitcoinTestnet => ApiServiceConstants.publicElectrumTestUrl,
          Network.liquidMainnet =>
            ApiServiceConstants.publicLiquidElectrumUrlPath,
          Network.liquidTestnet =>
            ApiServiceConstants.publicliquidElectrumTestUrlPath,
        },
      final CustomElectrumServerModel custom => custom.url,
    };
  }

  ElectrumServerProvider get provider {
    return switch (this) {
      BullBitcoinElectrumServerModel _ => ElectrumServerProvider.bullBitcoin,
      BlockstreamElectrumServerModel _ => ElectrumServerProvider.blockstream,
      CustomElectrumServerModel _ => ElectrumServerProvider.custom,
    };
  }

  String? get socks5 {
    return switch (this) {
      final CustomElectrumServerModel custom => custom.socks5,
      BullBitcoinElectrumServerModel _ => null,
      BlockstreamElectrumServerModel _ => null,
    };
  }
}
