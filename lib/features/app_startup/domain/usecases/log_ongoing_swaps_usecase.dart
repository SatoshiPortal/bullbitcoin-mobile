import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class LogOngoingSwapsUsecase {
  final BoltzSwapRepository _mainnetBoltzSwapRepository;
  final BoltzSwapRepository _testnetBoltzSwapRepository;
  final SettingsRepository _settingsRepository;

  LogOngoingSwapsUsecase({
    required BoltzSwapRepository mainnetBoltzSwapRepository,
    required BoltzSwapRepository testnetBoltzSwapRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetBoltzSwapRepository = mainnetBoltzSwapRepository,
       _testnetBoltzSwapRepository = testnetBoltzSwapRepository,
       _settingsRepository = settingsRepository;

  Future<void> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      final repository = isTestnet
          ? _testnetBoltzSwapRepository
          : _mainnetBoltzSwapRepository;

      final allSwaps = await repository.getAllSwaps();

      // Filter out swaps in pending status
      final swapsToLog = allSwaps
          .where((swap) => swap.status != SwapStatus.pending)
          .toList();

      if (swapsToLog.isEmpty) {
        log.fine('App startup: No swaps found (excluding pending)');
        return;
      }

      log.fine(
        'App startup: Found ${swapsToLog.length} swap(s) (excluding pending)',
      );

      for (final swap in swapsToLog) {
        _logSwapDetails(swap);
      }
    } catch (e, st) {
      log.warning(
        'Failed to log swaps during app startup: $e',
        error: e,
        trace: st,
      );
    }
  }

  void _logSwapDetails(Swap swap) {
    final swapType = swap.type.name;
    final swapStatus = swap.status.name;
    final swapId = swap.id;
    final amountSat = swap.amountSat;

    switch (swap) {
      case LnSendSwap():
        log.fine(
          '{"type": "swap", "swapType": "$swapType", "swapId": "$swapId", "status": "$swapStatus", "sendTxid": "${swap.sendTxid}", "refundTxid": "${swap.refundTxid}", "amountSat": $amountSat, "walletId": "${swap.sendWalletId}"}',
        );
      case LnReceiveSwap():
        log.fine(
          '{"type": "swap", "swapType": "$swapType", "swapId": "$swapId", "status": "$swapStatus", "receiveTxid": "${swap.receiveTxid}", "amountSat": $amountSat, "walletId": "${swap.receiveWalletId}"}',
        );
      case ChainSwap():
        log.fine(
          '{"type": "swap", "swapType": "$swapType", "swapId": "$swapId", "status": "$swapStatus", "sendTxid": "${swap.sendTxid}", "receiveTxid": "${swap.receiveTxid}", "refundTxid": "${swap.refundTxid}", "paymentAmount": ${swap.paymentAmount}, "sendWalletId": "${swap.sendWalletId}", "receiveWalletId": "${swap.receiveWalletId}"}',
        );
    }
  }
}
