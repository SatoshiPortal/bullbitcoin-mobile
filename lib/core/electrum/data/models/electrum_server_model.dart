import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
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
    String? socks5,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    @Default(ElectrumServerStatus.unknown) ElectrumServerStatus status,
    @Default(false) bool isActive,
    @Default(0) int priority,
    @Default(false) bool isCustom,
  }) = _ElectrumServerModel;
  const ElectrumServerModel._();

  factory ElectrumServerModel.fromJson(Map<String, dynamic> json) =>
      _$ElectrumServerModelFromJson(json);

  ElectrumServer toEntity() {
    final network = Network.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );

    return ElectrumServer(
      url: url,
      network: network,
      socks5: socks5,
      stopGap: stopGap,
      timeout: timeout,
      retry: retry,
      validateDomain: validateDomain,
      status: status,
      isActive: isActive,
    );
  }

  factory ElectrumServerModel.fromEntity(ElectrumServer entity) {
    return ElectrumServerModel(
      url: entity.url,
      isTestnet: entity.network.isTestnet,
      isLiquid: entity.network.isLiquid,
      socks5: entity.socks5,
      stopGap: entity.stopGap,
      timeout: entity.timeout,
      retry: entity.retry,
      validateDomain: entity.validateDomain,
      status: entity.status,
      isActive: entity.isActive,
      priority: switch (entity.electrumServerProvider) {
        CustomElectrumServerProvider() => 0,
        DefaultServerProvider(:final defaultServerProvider) =>
          switch (defaultServerProvider) {
            DefaultElectrumServerProvider.bullBitcoin => 1,
            DefaultElectrumServerProvider.blockstream => 2,
          },
      },
      isCustom: entity.electrumServerProvider is CustomElectrumServerProvider,
    );
  }

  factory ElectrumServerModel.fromSqlite(ElectrumServerRow row) {
    return ElectrumServerModel(
      url: row.url,
      socks5: row.socks5,
      retry: row.retry,
      timeout: row.timeout,
      stopGap: row.stopGap,
      validateDomain: row.validateDomain,
      isTestnet: row.isTestnet,
      isLiquid: row.isLiquid,
      priority: row.priority,
      isActive: row.isActive,
      isCustom: row.isCustom,
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
      isCustom: isCustom,
    );
  }
}
