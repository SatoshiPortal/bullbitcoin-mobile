import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class FixPrematureCompletedSwapUsecase {
  final BoltzStorageDatasource _boltzStorage;

  static const _swapId = ''; // TODO: add the swapID here

  FixPrematureCompletedSwapUsecase({
    required BoltzStorageDatasource boltzStorage,
  }) : _boltzStorage = boltzStorage;

  Future<void> execute() async {
    try {
      final swap = await _boltzStorage.fetch(_swapId);
      if (swap == null) {
        log.fine('FixSwap: swap $_swapId not found in SQLite');
        return;
      }

      if (swap is! ChainSwapModel) {
        log.fine(
          'FixSwap: swap $_swapId is not a ChainSwapModel, got ${swap.runtimeType}',
        );
        return;
      }

      log.fine('FixSwap: found swap $_swapId');
      log.fine('FixSwap:   status: ${swap.status}');
      log.fine('FixSwap:   type: ${swap.type}');
      log.fine('FixSwap:   isTestnet: ${swap.isTestnet}');
      log.fine('FixSwap:   keyIndex: ${swap.keyIndex}');
      log.fine('FixSwap:   creationTime: ${swap.creationTime}');
      log.fine('FixSwap:   sendWalletId: ${swap.sendWalletId}');
      log.fine('FixSwap:   sendTxid: ${swap.sendTxid}');
      log.fine('FixSwap:   paymentAddress: ${swap.paymentAddress}');
      log.fine('FixSwap:   paymentAmount: ${swap.paymentAmount}');
      log.fine('FixSwap:   receiveWalletId: ${swap.receiveWalletId}');
      log.fine('FixSwap:   receiveAddress: ${swap.receiveAddress}');
      log.fine('FixSwap:   receiveTxid: ${swap.receiveTxid}');
      log.fine('FixSwap:   refundAddress: ${swap.refundAddress}');
      log.fine('FixSwap:   refundTxid: ${swap.refundTxid}');
      log.fine('FixSwap:   completionTime: ${swap.completionTime}');
      log.fine('FixSwap:   boltzFees: ${swap.boltzFees}');
      log.fine('FixSwap:   lockupFees: ${swap.lockupFees}');
      log.fine('FixSwap:   claimFees: ${swap.claimFees}');
      log.fine('FixSwap:   serverNetworkFees: ${swap.serverNetworkFees}');

      if (swap.status == SwapStatus.completed.name) {
        final updated = swap.copyWith(
          status: SwapStatus.claimable.name,
          completionTime: null,
        );
        await _boltzStorage.store(updated);
        log.fine('FixSwap: updated swap $_swapId status to claimable');
      } else {
        log.fine(
          'FixSwap: swap $_swapId status is ${swap.status}, not updating',
        );
      }
    } catch (e) {
      log.severe(
        message: 'FixSwap: failed to fix swap $_swapId',
        error: e,
        trace: StackTrace.current,
      );
    }
  }
}
