import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

extension ElectrumServerModelMapper on ElectrumServerModel {
  static ElectrumServerModel fromEntity(ElectrumServer entity) {
    ElectrumServerModelProvider? a ;
    switch (entity.electrumServerProvider) {
      case value:
        
        break;
      default:
    } 
    return ElectrumServerModel(
      retry: entity.retry,
      timeout: entity.timeout,
      stopGap: entity.stopGap,
      validateDomain: entity.validateDomain,
      isTestnet: entity.network.isTestnet,
      isLiquid: entity.network.isLiquid,
      priority: entity.priority,
      url: entity.url,
      provider: ,
      isActive: entity.isActive,
    );
  }

  ElectrumServer toEntity() {
    return ElectrumServer(
      url: url,
      network: Network.fromEnvironment(
        isTestnet: isTestnet,
        isLiquid: isLiquid,
      ),
      socks5: socks5,
      stopGap: stopGap,
      timeout: timeout,
      retry: retry,
      validateDomain: validateDomain,
      isActive: isActive,
      electrumServerProvider: provider,
    );
  }
}
