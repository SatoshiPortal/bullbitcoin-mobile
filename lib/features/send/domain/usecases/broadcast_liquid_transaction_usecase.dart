import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bb_mobile/features/send/data/broadcast_failure_mapper.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class BroadcastLiquidTransactionUsecase {
  final LiquidBlockchainRepository _liquidBlockchain;
  final SettingsRepository _settingsRepository;

  BroadcastLiquidTransactionUsecase({
    required LiquidBlockchainRepository liquidBlockchainRepository,
    required this._settingsRepository,
  }) : _liquidBlockchain = liquidBlockchainRepository;

  Future<String> execute(
    String signedPset, {
    Network? network,
    bool? isTestnet,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      if (network != null && isTestnet != null) {
        throw ArgumentError('Specify one network context');
      }
      network ??= isTestnet == null
          ? Network.fromEnvironment(
              environment: settings.environment.networkEnv,
              isLiquid: true,
            )
          : isTestnet
          ? Network.liquidTestnet
          : Network.liquidMainnet;
      if (!network.isMainnet &&
          (settings.isSuperuser != true || settings.isDevModeEnabled != true)) {
        log.warning('Liquid broadcast refused category=authorization');
        throw CategorizedBroadcastException(
          BroadcastFailureCategory.authorization,
        );
      }
      return await _liquidBlockchain.broadcastTransaction(
        signedPset: signedPset,
        network: network,
      );
    } on Exception catch (e) {
      throw CategorizedBroadcastException(mapBroadcastFailure(e));
    }
  }
}
