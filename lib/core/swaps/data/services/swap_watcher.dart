import 'dart:async';

import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip21_uri/bip21_uri.dart';

class SwapWatcherService {
  final BoltzSwapRepository _boltzRepo;
  final WalletAddressRepository _walletAddressRepository;
  final FeesRepository _feesRepository;
  final SettingsRepository _settingsRepository;

  final StreamController<Swap> _swapStreamController =
      StreamController<Swap>.broadcast();
  StreamSubscription<Swap>? _swapStreamSubscription;

  SwapWatcherService({
    required BoltzSwapRepository boltzRepo,
    required WalletAddressRepository walletAddressRepository,
    required FeesRepository feesRepository,
    required SettingsRepository settingsRepository,
  }) : _boltzRepo = boltzRepo,
       _walletAddressRepository = walletAddressRepository,
       _feesRepository = feesRepository,
       _settingsRepository = settingsRepository {
    unawaited(startWatching());
  }

  Stream<Swap> get swapStream => _swapStreamController.stream;

  Future<void> startWatching() async {
    await _swapStreamSubscription?.cancel();
    _swapStreamSubscription = _boltzRepo.swapUpdatesStream.listen(
      (swap) async {
        log.info(
          '{"swapId": "${swap.id}", "status": "${swap.status.name}", "function": "startWatching"}',
        );
        _swapStreamController.add(swap);
        await processSwap(swap);
      },
      onError: (error) {
        log.severe('Swap stream error in watcher: $error');
      },
      onDone: () {
        log.info('Swap stream done in watcher.');
      },
      cancelOnError: false,
    );
    log.info('Swap watcher started and listening');
  }

  Future<void> restartWatcherWithOngoingSwaps() async {
    await _swapStreamSubscription?.cancel();
    final swaps = await _boltzRepo.getOngoingSwaps();
    final swapIdsToWatch = swaps.map((swap) => swap.id).toList();
    await _boltzRepo.reinitializeStreamWithSwaps(swapIds: swapIdsToWatch);
    await startWatching();
  }

  Future<void> processSwap(Swap swap) async {
    log.info(
      '{"swapId": "${swap.id}", "status": "${swap.status.name}", "function": "processSwap", "action": "started", "timestamp": "${DateTime.now().toIso8601String()}"}',
    );
    try {
      switch (swap.status) {
        case SwapStatus.claimable:
          switch (swap.type) {
            case SwapType.lightningToBitcoin:
              await _processReceiveLnToBitcoinClaim(
                swap: swap as LnReceiveSwap,
              );
            case SwapType.lightningToLiquid:
              await _processReceiveLnToLiquidClaim(swap: swap as LnReceiveSwap);
            case SwapType.liquidToBitcoin:
              await _processChainLiquidToBitcoinClaim(swap: swap as ChainSwap);
            case SwapType.bitcoinToLiquid:
              await _processChainBitcoinToLiquidClaim(swap: swap as ChainSwap);
            default:
              return;
          }
        case SwapStatus.refundable:
          switch (swap.type) {
            case SwapType.bitcoinToLightning:
              await _processSendBitcoinToLnRefund(swap: swap as LnSendSwap);
            case SwapType.liquidToLightning:
              await _processSendLiquidToLnRefund(swap: swap as LnSendSwap);
            case SwapType.liquidToBitcoin:
              await _processChainLiquidToBitcoinRefund(swap: swap as ChainSwap);
            case SwapType.bitcoinToLiquid:
              await _processChainBitcoinToLiquidRefund(swap: swap as ChainSwap);
            default:
              return;
          }

        case SwapStatus.canCoop:
          switch (swap.type) {
            case SwapType.bitcoinToLightning:
              await _processSendBitcoinToLnCoopSign(swap: swap as LnSendSwap);
            case SwapType.liquidToLightning:
              await _processSendLiquidToLnCoopSign(swap: swap as LnSendSwap);
            default:
              return;
          }

        case SwapStatus.completed:
          await _processCompletedSwap(swap: swap);

        case SwapStatus.pending:
        case SwapStatus.paid:
        case SwapStatus.expired:
        case SwapStatus.failed:
          return;
      }
      // ignore: empty_catches
    } catch (e) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "processSwap", "action": "error", "error": "$e", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
    } finally {
      log.info(
        '{"swapId": "${swap.id}", "status": "${swap.status.name}", "function": "processSwap", "action": "completed", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
    }
  }

  Future<void> _processReceiveLnToBitcoinClaim({
    required LnReceiveSwap swap,
  }) async {
    try {
      final receiveAddress = swap.receiveAddress;
      if (receiveAddress == null) {
        throw Exception('Receive address is null');
      }
      String claimTxId;
      try {
        claimTxId = await _boltzRepo.claimLightningToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          bitcoinAddress: swap.receiveAddress!,
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop claim failed. Attempting script path spend"}',
          error: e,
          trace: st,
        );
        claimTxId = await _boltzRepo.claimLightningToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          bitcoinAddress: swap.receiveAddress!,
          cooperate: false,
        );
      }
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxId,
        receiveAddress: swap.receiveAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processReceiveLnToBitcoinClaim"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _processSendBitcoinToLnRefund({required LnSendSwap swap}) async {
    try {
      String refundAddress;
      if (swap.refundAddress != null) {
        refundAddress = swap.refundAddress!;
      } else {
        final address = await _walletAddressRepository
            .generateNewReceiveAddress(walletId: swap.sendWalletId);
        refundAddress = address.address;
        final updatedSwap = swap.copyWith(refundAddress: refundAddress);
        await _boltzRepo.updateSwap(swap: updatedSwap);
      }

      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: true,
      );
      final networkFee = await _feesRepository.getNetworkFees(network: network);
      final txSize = await _boltzRepo.getSwapRefundTxSize(
        swapId: swap.id,
        swapType: swap.type,
      );
      final absoluteFeeOptions = networkFee.toAbsolute(txSize);
      String refundTxid;
      int actualFeesUsed;
      log.info(
        '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnRefund", "action": "coop_refund_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        actualFeesUsed = absoluteFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundBitcoinToLightningSwap(
          swapId: swap.id,
          bitcoinAddress: refundAddress,
          absoluteFees: actualFeesUsed,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnRefund", "action": "coop_refund_succeeded", "txId": "$refundTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop refund failed. Attempting script path spend", "action": "coop_refund_failed_fallback_script", "timestamp": "${DateTime.now().toIso8601String()}"}',
          error: e,
          trace: st,
        );
        final scriptPathTxSize = await _boltzRepo.getSwapRefundTxSize(
          swapId: swap.id,
          swapType: swap.type,
          isCooperative: false,
        );
        final scriptPathFeeOptions = networkFee.toAbsolute(scriptPathTxSize);
        actualFeesUsed = scriptPathFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundBitcoinToLightningSwap(
          swapId: swap.id,
          bitcoinAddress: refundAddress,
          absoluteFees: actualFeesUsed,
          cooperate: false,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnRefund", "action": "script_path_refund_succeeded", "txId": "$refundTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      }
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: refundAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
        fees: swap.fees?.copyWith(claimFee: actualFeesUsed),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnRefund"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _processReceiveLnToLiquidClaim({
    required LnReceiveSwap swap,
  }) async {
    try {
      final receiveAddress = swap.receiveAddress;
      if (receiveAddress == null) {
        throw Exception('Receive address is null');
      }
      String claimTxId;
      log.info(
        '{"swapId": "${swap.id}", "function": "_processReceiveLnToLiquidClaim", "action": "coop_claim_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          liquidAddress: receiveAddress,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processReceiveLnToLiquidClaim", "action": "coop_claim_succeeded", "txId": "$claimTxId", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop claim failed. Attempting script path spend", "action": "coop_claim_failed_fallback_script", "timestamp": "${DateTime.now().toIso8601String()}"}',
          error: e,
          trace: st,
        );
        claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          liquidAddress: receiveAddress,
          cooperate: false,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processReceiveLnToLiquidClaim", "action": "script_path_claim_succeeded", "txId": "$claimTxId", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      }
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxId,
        receiveAddress: receiveAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processReceiveLnToLiquidClaim"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _processSendLiquidToLnRefund({required LnSendSwap swap}) async {
    try {
      String refundAddress;
      if (swap.refundAddress != null) {
        refundAddress = swap.refundAddress!;
      } else {
        final address = await _walletAddressRepository
            .generateNewReceiveAddress(walletId: swap.sendWalletId);
        refundAddress = address.address;
        final updatedSwap = swap.copyWith(refundAddress: refundAddress);
        await _boltzRepo.updateSwap(swap: updatedSwap);
      }
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: true,
      );
      final networkFee = await _feesRepository.getNetworkFees(network: network);
      final txSize = await _boltzRepo.getSwapRefundTxSize(
        swapId: swap.id,
        swapType: swap.type,
      );
      final absoluteFeeOptions = networkFee.toAbsolute(txSize);
      String refundTxid;
      int actualFeesUsed;
      log.info(
        '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnRefund", "action": "coop_refund_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        actualFeesUsed = absoluteFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundLiquidToLightningSwap(
          swapId: swap.id,
          liquidAddress: refundAddress,
          absoluteFees: actualFeesUsed,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnRefund", "action": "coop_refund_succeeded", "txId": "$refundTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop refund failed. Attempting script path spend", "action": "coop_refund_failed_fallback_script", "timestamp": "${DateTime.now().toIso8601String()}"}',
          error: e,
          trace: st,
        );
        final scriptPathTxSize = await _boltzRepo.getSwapRefundTxSize(
          swapId: swap.id,
          swapType: swap.type,
          isCooperative: false,
        );
        final scriptPathFeeOptions = networkFee.toAbsolute(scriptPathTxSize);
        actualFeesUsed = scriptPathFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundLiquidToLightningSwap(
          swapId: swap.id,
          liquidAddress: refundAddress,
          absoluteFees: actualFeesUsed,
          cooperate: false,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnRefund", "action": "script_path_refund_succeeded", "txId": "$refundTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      }
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: refundAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
        fees: swap.fees?.copyWith(claimFee: actualFeesUsed),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnRefund"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _processSendBitcoinToLnCoopSign({
    required LnSendSwap swap,
  }) async {
    log.info(
      '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnCoopSign", "action": "coop_close_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
    );
    try {
      await _boltzRepo.coopSignBitcoinToLightningSwap(swapId: swap.id);
      log.info(
        '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnCoopSign", "action": "coop_close_succeeded", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnCoopSign", "action": "coop_close_failed", "timestamp": "${DateTime.now().toIso8601String()}"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _processSendLiquidToLnCoopSign({
    required LnSendSwap swap,
  }) async {
    log.info(
      '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnCoopSign", "action": "coop_close_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
    );
    try {
      final isBatched = swap.paymentAmount < 1000;
      if (isBatched) {
        final updatedSwap = swap.copyWith(
          status: SwapStatus.completed,
          completionTime: DateTime.now(),
        );
        await _boltzRepo.updateSwap(swap: updatedSwap);
        log.info(
          '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnCoopSign", "action": "batched_completed", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      } else {
        await _boltzRepo.coopSignLiquidToLightningSwap(swapId: swap.id);
        log.info(
          '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnCoopSign", "action": "coop_close_succeeded", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      }
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnCoopSign", "action": "coop_close_failed", "timestamp": "${DateTime.now().toIso8601String()}"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _processChainLiquidToBitcoinClaim({
    required ChainSwap swap,
  }) async {
    try {
      String finalClaimAddress;
      if (swap.receiveWalletId != null) {
        if (swap.receiveAddress != null) {
          // Use existing receive address if available
          if (swap.receiveAddress!.startsWith('bitcoin:')) {
            final uri = bip21.decode(swap.receiveAddress!);
            final address = uri.address;
            finalClaimAddress = address;
          } else {
            finalClaimAddress = swap.receiveAddress!;
          }
        } else {
          // Generate new address and store it in the swap model
          final claimAddress = await _walletAddressRepository
              .generateNewReceiveAddress(walletId: swap.receiveWalletId!);
          finalClaimAddress = claimAddress.address;
          final updatedSwap = swap.copyWith(receiveAddress: finalClaimAddress);
          await _boltzRepo.updateSwap(swap: updatedSwap);
        }
      } else {
        if (swap.receiveAddress!.startsWith('bitcoin:')) {
          final uri = bip21.decode(swap.receiveAddress!);
          final address = uri.address;
          finalClaimAddress = address;
        } else {
          finalClaimAddress = swap.receiveAddress!;
        }
      }
      String claimTxid;
      log.info(
        '{"swapId": "${swap.id}", "function": "_processChainLiquidToBitcoinClaim", "action": "coop_claim_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        claimTxid = await _boltzRepo.claimLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          bitcoinClaimAddress: finalClaimAddress,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processChainLiquidToBitcoinClaim", "action": "coop_claim_succeeded", "txId": "$claimTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop claim failed. Attempting script path spend", "action": "coop_claim_failed_fallback_script", "timestamp": "${DateTime.now().toIso8601String()}"}',
          error: e,
          trace: st,
        );
        claimTxid = await _boltzRepo.claimLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          bitcoinClaimAddress: finalClaimAddress,
          cooperate: false,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processChainLiquidToBitcoinClaim", "action": "script_path_claim_succeeded", "txId": "$claimTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      }
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxid,
        receiveAddress: finalClaimAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processChainLiquidToBitcoinClaim"',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _processChainBitcoinToLiquidRefund({
    required ChainSwap swap,
  }) async {
    try {
      String refundAddress;
      if (swap.refundAddress != null) {
        refundAddress = swap.refundAddress!;
      } else {
        final address = await _walletAddressRepository
            .generateNewReceiveAddress(walletId: swap.sendWalletId);
        refundAddress = address.address;
        final updatedSwap = swap.copyWith(refundAddress: refundAddress);
        await _boltzRepo.updateSwap(swap: updatedSwap);
      }
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: false,
      );
      final networkFee = await _feesRepository.getNetworkFees(network: network);
      final txSize = await _boltzRepo.getSwapRefundTxSize(
        swapId: swap.id,
        swapType: swap.type,
        refundAddressForChainSwaps: refundAddress,
      );
      final absoluteFeeOptions = networkFee.toAbsolute(txSize);
      String refundTxid;
      int actualFeesUsed;
      log.info(
        '{"swapId": "${swap.id}", "function": "_processChainBitcoinToLiquidRefund", "action": "coop_refund_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        actualFeesUsed = absoluteFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: actualFeesUsed,
          bitcoinRefundAddress: refundAddress,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processChainBitcoinToLiquidRefund", "action": "coop_refund_succeeded", "txId": "$refundTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop refund failed. Attempting script path spend", "action": "coop_refund_failed_fallback_script", "timestamp": "${DateTime.now().toIso8601String()}"}',
          error: e,
          trace: st,
        );
        final scriptPathTxSize = await _boltzRepo.getSwapRefundTxSize(
          swapId: swap.id,
          swapType: swap.type,
          isCooperative: false,
          refundAddressForChainSwaps: refundAddress,
        );
        final scriptPathFeeOptions = networkFee.toAbsolute(scriptPathTxSize);
        actualFeesUsed = scriptPathFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: actualFeesUsed,
          bitcoinRefundAddress: refundAddress,
          cooperate: false,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processChainBitcoinToLiquidRefund", "action": "script_path_refund_succeeded", "txId": "$refundTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      }
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: refundAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
        fees: swap.fees?.copyWith(claimFee: actualFeesUsed),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processChainBitcoinToLiquidRefund"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _processChainBitcoinToLiquidClaim({
    required ChainSwap swap,
  }) async {
    try {
      String finalClaimAddress;
      if (swap.receiveWalletId != null) {
        if (swap.receiveAddress != null) {
          // Use existing receive address if available
          if (swap.receiveAddress!.startsWith('liquidnetwork:') ||
              swap.receiveAddress!.startsWith('liquidtestnet:')) {
            final uri = bip21.decode(swap.receiveAddress!);
            final address = uri.address;
            finalClaimAddress = address;
          } else {
            finalClaimAddress = swap.receiveAddress!;
          }
        } else {
          // Generate new address and store it in the swap model
          final claimAddress = await _walletAddressRepository
              .generateNewReceiveAddress(walletId: swap.receiveWalletId!);
          finalClaimAddress = claimAddress.address;
          final updatedSwap = swap.copyWith(receiveAddress: finalClaimAddress);
          await _boltzRepo.updateSwap(swap: updatedSwap);
        }
      } else {
        if (swap.receiveAddress!.startsWith('liquidnetwork:') ||
            swap.receiveAddress!.startsWith('liquidtestnet:')) {
          final uri = bip21.decode(swap.receiveAddress!);
          final address = uri.address;
          finalClaimAddress = address;
        } else {
          finalClaimAddress = swap.receiveAddress!;
        }
      }

      String claimTxid;
      log.info(
        '{"swapId": "${swap.id}", "function": "_processChainBitcoinToLiquidClaim", "action": "coop_claim_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        claimTxid = await _boltzRepo.claimBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          liquidClaimAddress: finalClaimAddress,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processChainBitcoinToLiquidClaim", "action": "coop_claim_succeeded", "txId": "$claimTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop claim failed. Attempting script path spend", "action": "coop_claim_failed_fallback_script", "timestamp": "${DateTime.now().toIso8601String()}"}',
          error: e,
          trace: st,
        );
        claimTxid = await _boltzRepo.claimBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee! + 21, // t
          liquidClaimAddress: finalClaimAddress,
          cooperate: false,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processChainBitcoinToLiquidClaim", "action": "script_path_claim_succeeded", "txId": "$claimTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      }
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxid,
        receiveAddress: finalClaimAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processChainBitcoinToLiquidClaim"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _processChainLiquidToBitcoinRefund({
    required ChainSwap swap,
  }) async {
    try {
      String refundAddress;
      if (swap.refundAddress != null) {
        refundAddress = swap.refundAddress!;
      } else {
        final address = await _walletAddressRepository
            .generateNewReceiveAddress(walletId: swap.sendWalletId);
        refundAddress = address.address;
        final updatedSwap = swap.copyWith(refundAddress: refundAddress);
        await _boltzRepo.updateSwap(swap: updatedSwap);
      }
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: true,
      );
      final networkFee = await _feesRepository.getNetworkFees(network: network);
      final txSize = await _boltzRepo.getSwapRefundTxSize(
        swapId: swap.id,
        swapType: swap.type,
        refundAddressForChainSwaps: refundAddress,
      );
      final absoluteFeeOptions = networkFee.toAbsolute(txSize);
      String refundTxid;
      int actualFeesUsed;
      log.info(
        '{"swapId": "${swap.id}", "function": "_processChainLiquidToBitcoinRefund", "action": "coop_refund_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        actualFeesUsed = absoluteFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: actualFeesUsed,
          liquidRefundAddress: refundAddress,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processChainLiquidToBitcoinRefund", "action": "coop_refund_succeeded", "txId": "$refundTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop refund failed. Attempting script path spend", "action": "coop_refund_failed_fallback_script", "timestamp": "${DateTime.now().toIso8601String()}"}',
          error: e,
          trace: st,
        );
        final scriptPathTxSize = await _boltzRepo.getSwapRefundTxSize(
          swapId: swap.id,
          swapType: swap.type,
          isCooperative: false,
        );
        final scriptPathFeeOptions = networkFee.toAbsolute(scriptPathTxSize);
        actualFeesUsed = scriptPathFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: actualFeesUsed,
          liquidRefundAddress: refundAddress,
          cooperate: false,
        );
        log.info(
          '{"swapId": "${swap.id}", "function": "_processChainLiquidToBitcoinRefund", "action": "script_path_refund_succeeded", "txId": "$refundTxid", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      }
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: refundAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
        fees: swap.fees?.copyWith(claimFee: actualFeesUsed),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processChainLiquidToBitcoinRefund"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _processCompletedSwap({required Swap swap}) async {
    try {
      log.info(
        '{"swapId": "${swap.id}", "status": "completed", "function": "_processCompletedSwap"}',
      );

      switch (swap.type) {
        case SwapType.lightningToBitcoin:
        case SwapType.lightningToLiquid:
          if (swap is LnReceiveSwap && swap.receiveTxid == null) {
            final updatedSwap = swap.copyWith(status: SwapStatus.claimable);
            await _boltzRepo.updateSwap(swap: updatedSwap);
          } else {
            return;
          }
        case SwapType.bitcoinToLightning:
        case SwapType.liquidToLightning:
        case SwapType.liquidToBitcoin:
        case SwapType.bitcoinToLiquid:
      }
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processCompletedWithoutTransaction"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }
}
