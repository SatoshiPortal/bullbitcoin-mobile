import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class RescueOrphanedSwapUsecase {
  static const _swapId = ''; // TODO: add swap ID here
  static const _sendTxid = ''; // TODO: add sendTxId here

  final BoltzStorageDatasource _boltzStorage;
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  RescueOrphanedSwapUsecase({
    required BoltzStorageDatasource boltzStorage,
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
  }) : _boltzStorage = boltzStorage,
       _walletRepository = walletRepository,
       _settingsRepository = settingsRepository;

  Future<void> execute() async {
    log.info('Rescue: Starting rescue for swap $_swapId');

    final existing = await _boltzStorage.fetch(_swapId);
    if (existing != null) {
      log.info(
        'Rescue: Swap $_swapId already exists in SQLite with status: ${existing.status}, skipping',
      );
      return;
    }
    log.info('Rescue: Swap $_swapId not found in SQLite');

    log.info('Rescue: Fetching LbtcLnSwap from secure storage');
    final lbtcLnSwap = await _boltzStorage.fetchLbtcLnSwap(_swapId);
    log.info(
      'Rescue: Found LbtcLnSwap in secure storage: '
      '{"id": "${lbtcLnSwap.id}", "keyIndex": ${lbtcLnSwap.keyIndex}, '
      '"outAmount": ${lbtcLnSwap.outAmount}, '
      '"scriptAddress": "${lbtcLnSwap.scriptAddress}", '
      '"network": "${lbtcLnSwap.network}"}',
    );

    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;
    log.info('Rescue: Environment isTestnet=$isTestnet');

    final liquidWallets = await _walletRepository.getWallets(
      environment: settings.environment,
      onlyLiquid: true,
      onlyDefaults: true,
    );
    if (liquidWallets.isEmpty) {
      log.warning('Rescue: No liquid wallet found, cannot rescue swap');
      return;
    }
    final sendWalletId = liquidWallets.first.id;
    log.info('Rescue: Using liquid wallet $sendWalletId');

    final swapModel = SwapModel.lnSend(
      id: lbtcLnSwap.id,
      status: SwapStatus.refundable.name,
      type: SwapType.liquidToLightning.name,
      isTestnet: isTestnet,
      keyIndex: lbtcLnSwap.keyIndex.toInt(),
      creationTime: DateTime.now().millisecondsSinceEpoch,
      sendWalletId: sendWalletId,
      invoice: lbtcLnSwap.invoice,
      paymentAddress: lbtcLnSwap.scriptAddress,
      paymentAmount: lbtcLnSwap.outAmount.toInt(),
      sendTxid: _sendTxid,
    );
    log.info(
      'Rescue: Built SwapModel: '
      '{"id": "${swapModel.id}", "status": "${swapModel.status}", '
      '"type": "${swapModel.type}", "sendTxid": "$_sendTxid", '
      '"paymentAmount": ${lbtcLnSwap.outAmount.toInt()}, '
      '"sendWalletId": "$sendWalletId"}',
    );

    await _boltzStorage.store(swapModel);
    log.info('Rescue: Successfully stored swap $_swapId in SQLite');

    final verification = await _boltzStorage.fetch(_swapId);
    if (verification != null) {
      log.info(
        'Rescue: Verified swap in SQLite: '
        '{"id": "${verification.id}", "status": "${verification.status}"}',
      );
    } else {
      log.warning('Rescue: Verification failed - swap not found after store');
    }
  }
}
