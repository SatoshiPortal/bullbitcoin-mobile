import 'dart:async';

import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart';
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
  final Set<String> _processingSwapIds = {};

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
        log.fine(
          '{"swapId": "${swap.id}", "status": "${swap.status.name}", "function": "startWatching"}',
        );
        _swapStreamController.add(swap);
        await processSwap(swap);
      },
      onError: (error) {
        log.severe(
          message: 'Swap stream error in watcher',
          error: error,
          trace: StackTrace.current,
        );
      },
      onDone: () {
        log.fine('Swap stream done in watcher.');
      },
      cancelOnError: false,
    );
    log.fine('Swap watcher started and listening');
  }

  Future<void> restartWatcherWithOngoingSwaps() async {
    await _swapStreamSubscription?.cancel();
    final swaps = await _boltzRepo.getOngoingSwaps();
    final swapIdsRaw = swaps.map((swap) => swap.id).toList();
    final swapIdsToWatch = swapIdsRaw.toSet().toList();

    await _boltzRepo.reinitializeStreamWithSwaps(swapIds: swapIdsToWatch);
    await startWatching();
  }

  Future<void> processSwap(Swap swap) async {
    if (_processingSwapIds.contains(swap.id)) {
      log.fine(
        '{"swapId": "${swap.id}", "status": "${swap.status.name}", "function": "processSwap", "action": "delaying_already_processing", "currentlyProcessing": true, "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      await Future.delayed(const Duration(seconds: 3));
      // return;
    }

    _processingSwapIds.add(swap.id);
    log.fine(
      '{"swapId": "${swap.id}", "status": "${swap.status.name}", "function": "processSwap", "action": "started", "timestamp": "${DateTime.now().toIso8601String()}"}',
    );
    try {
      switch (swap.status) {
        case SwapStatus.claimable:
          switch (swap.type) {
            case SwapType.lightningToBitcoin:
              await _claimReceiveLnToBitcoin(swap: swap as LnReceiveSwap);
            case SwapType.lightningToLiquid:
              await _claimReceiveLnToLiquid(swap: swap as LnReceiveSwap);
            case SwapType.liquidToBitcoin:
              await _claimChainLiquidToBitcoin(swap: swap as ChainSwap);
            case SwapType.bitcoinToLiquid:
              await _claimChainBitcoinToLiquid(swap: swap as ChainSwap);
            default:
              return;
          }
        case SwapStatus.refundable:
          switch (swap.type) {
            case SwapType.bitcoinToLightning:
              await _refundSendBitcoinToLn(swap: swap as LnSendSwap);
            case SwapType.liquidToLightning:
              await _refundSendLiquidToLn(swap: swap as LnSendSwap);
            case SwapType.liquidToBitcoin:
              await _refundChainLiquidToBitcoin(swap: swap as ChainSwap);
            case SwapType.bitcoinToLiquid:
              await _refundChainBitcoinToLiquid(swap: swap as ChainSwap);
            default:
              return;
          }

        case SwapStatus.canCoop:
          switch (swap.type) {
            case SwapType.bitcoinToLightning:
              await _coopCloseSendBitcoinToLn(swap: swap as LnSendSwap);
            case SwapType.liquidToLightning:
              await _coopCloseSendLiquidToLn(swap: swap as LnSendSwap);
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
        message: 'Error processing swap',
        error: e,
        trace: StackTrace.current,
      );
    } finally {
      Future.delayed(const Duration(seconds: 1), () {
        _processingSwapIds.remove(swap.id);
        log.fine(
          '{"swapId": "${swap.id}", "status": "${swap.status.name}", "function": "processSwap", "action": "completed", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      });
    }
  }

  Future<void> _claimReceiveLnToBitcoin({required LnReceiveSwap swap}) async {
    try {
      if (swap.receiveTxid != null) {
        return;
      }
      final receiveAddress = swap.receiveAddress;
      if (receiveAddress == null) {
        throw Exception('Receive address is null');
      }

      // Unsubscribe BEFORE claiming to prevent race condition with WebSocket updates
      _boltzRepo.unsubscribeFromSwaps([swap.id]);

      String claimTxId;
      try {
        claimTxId = await _boltzRepo.claimLightningToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          bitcoinAddress: swap.receiveAddress!,
        );
      } catch (e, st) {
        log.severe(
          message: "Coop claim failed. Attempting script path spend",
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
        fees: swap.fees?.copyWith(claimFee: swap.fees!.claimFee),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(error: e, trace: st);

      // Check if transaction actually succeeded despite the error
      final recovered = await _checkAndRecoverFromOutspend(
        swap: swap,
        error: e,
        functionName: '_processReceiveLnToBitcoinClaim',
        isClaim: true,
      );
      if (recovered) return;

      // Re-subscribe on error so watcher continues monitoring
      _boltzRepo.subscribeToSwaps([swap.id]);
      rethrow;
    }
  }

  Future<void> _claimReceiveLnToLiquid({required LnReceiveSwap swap}) async {
    try {
      if (swap.receiveTxid != null) {
        return;
      }
      final receiveAddress = swap.receiveAddress;
      if (receiveAddress == null) {
        throw Exception('Receive address is null');
      }

      // Unsubscribe BEFORE claiming to prevent race condition with WebSocket updates
      _boltzRepo.unsubscribeFromSwaps([swap.id]);

      String claimTxId;
      log.fine(
        '{"swapId": "${swap.id}", "function": "_processReceiveLnToLiquidClaim", "action": "coop_claim_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          liquidAddress: receiveAddress,
        );
      } catch (e, st) {
        log.severe(
          message:
              '"Coop claim failed. Attempting script path spend", "action": "coop_claim_failed_fallback_script", "timestamp": "${DateTime.now().toIso8601String()}"}',
          error: e,
          trace: st,
        );
        claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          liquidAddress: receiveAddress,
          cooperate: false,
        );
      }
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxId,
        receiveAddress: receiveAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
        fees: swap.fees?.copyWith(claimFee: swap.fees!.claimFee),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
      _swapStreamController.add(updatedSwap);
    } catch (e, st) {
      log.severe(error: e, trace: st);

      // Check if transaction actually succeeded despite the error
      final recovered = await _checkAndRecoverFromOutspend(
        swap: swap,
        error: e,
        functionName: '_processReceiveLnToLiquidClaim',
        isClaim: true,
      );
      if (recovered) return;

      // Re-subscribe on error so watcher continues monitoring
      _boltzRepo.subscribeToSwaps([swap.id]);
      rethrow;
    }
  }

  Future<void> _coopCloseSendBitcoinToLn({required LnSendSwap swap}) async {
    log.fine(
      '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnCoopSign", "action": "coop_close_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
    );
    try {
      if (swap.preimage == null) {
        final preimage = await _boltzRepo.getSendSwapPreimage(swapId: swap.id);
        if (preimage != null) {
          await _boltzRepo.updateSwap(swap: swap.copyWith(preimage: preimage));
        }
      }
      await _boltzRepo.coopSignBitcoinToLightningSwap(swapId: swap.id);
      log.fine(
        '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnCoopSign", "action": "coop_close_succeeded", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      final updatedSwap = swap.copyWith(
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(
        message:
            '"action": "coop_close_failed", "timestamp": "${DateTime.now().toIso8601String()}"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _coopCloseSendLiquidToLn({required LnSendSwap swap}) async {
    log.fine(
      '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnCoopSign", "action": "coop_close_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
    );
    try {
      final isBatched = swap.paymentAmount < 1000;
      if (isBatched) {
        // need to think about how to handle preimage for this
        log.fine(
          '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnCoopSign", "action": "batched_completed", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      } else {
        if (swap.preimage == null) {
          final preimage = await _boltzRepo.getSendSwapPreimage(
            swapId: swap.id,
          );
          if (preimage != null) {
            await _boltzRepo.updateSwap(
              swap: swap.copyWith(preimage: preimage),
            );
          }
        }
        await _boltzRepo.coopSignLiquidToLightningSwap(swapId: swap.id);
        log.fine(
          '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnCoopSign", "action": "coop_close_succeeded", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      }
      final updatedSwap = swap.copyWith(
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
      // Emit the updated swap so listeners (like SendCubit) receive the completion
      _swapStreamController.add(updatedSwap);
      _boltzRepo.unsubscribeFromSwaps([swap.id]);
    } catch (e, st) {
      log.severe(
        message:
            '"action": "coop_close_failed", "timestamp": "${DateTime.now().toIso8601String()}"}',
        error: e,
        trace: st,
      );
      rethrow;
    }
  }

  Future<void> _refundSendLiquidToLn({required LnSendSwap swap}) async {
    try {
      if (swap.refundTxid != null) {
        return;
      }
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

      // Unsubscribe BEFORE refunding to prevent race condition with WebSocket updates
      _boltzRepo.unsubscribeFromSwaps([swap.id]);

      String refundTxid;
      int actualFeesUsed;
      log.fine(
        '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnRefund", "action": "coop_refund_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        actualFeesUsed = absoluteFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundLiquidToLightningSwap(
          swapId: swap.id,
          liquidAddress: refundAddress,
          absoluteFees: actualFeesUsed,
        );
      } catch (e, st) {
        log.severe(
          message: "Coop refund failed. Attempting script path spend",
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
      log.severe(error: e, trace: st);

      // Check if transaction actually succeeded despite the error
      final recovered = await _checkAndRecoverFromOutspend(
        swap: swap,
        error: e,
        functionName: '_processSendLiquidToLnRefund',
        isClaim: false,
      );
      if (recovered) return;

      // Re-subscribe on error so watcher continues monitoring
      _boltzRepo.subscribeToSwaps([swap.id]);
      rethrow;
    }
  }

  Future<void> _refundSendBitcoinToLn({required LnSendSwap swap}) async {
    try {
      if (swap.refundTxid != null) {
        return;
      }
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
      );
      final absoluteFeeOptions = networkFee.toAbsolute(txSize);

      // Unsubscribe BEFORE refunding to prevent race condition with WebSocket updates
      _boltzRepo.unsubscribeFromSwaps([swap.id]);

      String refundTxid;
      int actualFeesUsed;
      log.fine(
        '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnRefund", "action": "coop_refund_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        actualFeesUsed = absoluteFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundBitcoinToLightningSwap(
          swapId: swap.id,
          bitcoinAddress: refundAddress,
          absoluteFees: actualFeesUsed,
        );
      } catch (e, st) {
        log.severe(
          message: "Coop refund failed. Attempting script path spend",
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
      log.severe(error: e, trace: st);

      // Check if transaction actually succeeded despite the error
      final recovered = await _checkAndRecoverFromOutspend(
        swap: swap,
        error: e,
        functionName: '_processSendBitcoinToLnRefund',
        isClaim: false,
      );
      if (recovered) return;

      // Re-subscribe on error so watcher continues monitoring
      _boltzRepo.subscribeToSwaps([swap.id]);
      rethrow;
    }
  }

  Future<void> _claimChainLiquidToBitcoin({required ChainSwap swap}) async {
    try {
      if (swap.receiveTxid != null) {
        return;
      }
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
      // Unsubscribe BEFORE claiming to prevent race condition with WebSocket updates
      _boltzRepo.unsubscribeFromSwaps([swap.id]);

      String claimTxid;
      log.fine(
        '{"swapId": "${swap.id}", "function": "_processChainLiquidToBitcoinClaim", "action": "coop_claim_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        claimTxid = await _boltzRepo.claimLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          bitcoinClaimAddress: finalClaimAddress,
        );
      } catch (e, st) {
        log.severe(
          message:
              '"Coop claim failed. Attempting script path spend", "action": "coop_claim_failed_fallback_script", "timestamp": "${DateTime.now().toIso8601String()}"}',
          error: e,
          trace: st,
        );
        claimTxid = await _boltzRepo.claimLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          bitcoinClaimAddress: finalClaimAddress,
          cooperate: false,
        );
      }
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxid,
        receiveAddress: finalClaimAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
        fees: swap.fees?.copyWith(claimFee: swap.fees!.claimFee),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(error: e, trace: st);

      // Check if transaction actually succeeded despite the error
      final recovered = await _checkAndRecoverFromOutspend(
        swap: swap,
        error: e,
        functionName: '_processChainLiquidToBitcoinClaim',
        isClaim: true,
      );
      if (recovered) return;

      // Re-subscribe on error so watcher continues monitoring
      _boltzRepo.subscribeToSwaps([swap.id]);
      rethrow;
    }
  }

  Future<void> _claimChainBitcoinToLiquid({required ChainSwap swap}) async {
    try {
      if (swap.receiveTxid != null) {
        return;
      }
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

      // Unsubscribe BEFORE claiming to prevent race condition with WebSocket updates
      _boltzRepo.unsubscribeFromSwaps([swap.id]);

      String claimTxid;
      log.fine(
        '{"swapId": "${swap.id}", "function": "_processChainBitcoinToLiquidClaim", "action": "coop_claim_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        claimTxid = await _boltzRepo.claimBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          liquidClaimAddress: finalClaimAddress,
        );
      } catch (e, st) {
        log.severe(
          message: "Coop claim failed. Attempting script path spend",
          error: e,
          trace: st,
        );
        claimTxid = await _boltzRepo.claimBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          liquidClaimAddress: finalClaimAddress,
          cooperate: false,
        );
      }
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxid,
        receiveAddress: finalClaimAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
        fees: swap.fees?.copyWith(claimFee: swap.fees!.claimFee),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      log.severe(error: e, trace: st);

      // Check if transaction actually succeeded despite the error
      final recovered = await _checkAndRecoverFromOutspend(
        swap: swap,
        error: e,
        functionName: '_processChainBitcoinToLiquidClaim',
        isClaim: true,
      );
      if (recovered) return;

      // Re-subscribe on error so watcher continues monitoring
      _boltzRepo.subscribeToSwaps([swap.id]);
      rethrow;
    }
  }

  Future<void> _refundChainLiquidToBitcoin({required ChainSwap swap}) async {
    try {
      // Log entire ChainSwap object for debugging
      log.fine(
        '{"swapId": "${swap.id}", "function": "_refundChainLiquidToBitcoin", "action": "entering_refund_flow", "swap": $swap, "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      if (swap.refundTxid != null) {
        return;
      }
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

      // Unsubscribe BEFORE refunding to prevent race condition with WebSocket updates
      _boltzRepo.unsubscribeFromSwaps([swap.id]);

      String refundTxid;
      int actualFeesUsed;
      log.fine(
        '{"swapId": "${swap.id}", "function": "_processChainLiquidToBitcoinRefund", "action": "coop_refund_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        actualFeesUsed = absoluteFeeOptions.fastest.value.toInt() + 3;
        refundTxid = await _boltzRepo.refundLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: actualFeesUsed,
          liquidRefundAddress: refundAddress,
        );
      } catch (e, st) {
        log.severe(
          message: "Coop refund failed. Attempting script path spend",
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
        actualFeesUsed = scriptPathFeeOptions.fastest.value.toInt() + 3;
        refundTxid = await _boltzRepo.refundLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: actualFeesUsed,
          liquidRefundAddress: refundAddress,
          cooperate: false,
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
      log.severe(error: e, trace: st);

      // Check if transaction actually succeeded despite the error
      final recovered = await _checkAndRecoverFromOutspend(
        swap: swap,
        error: e,
        functionName: '_processChainLiquidToBitcoinRefund',
        isClaim: false,
      );
      if (recovered) return;

      // Re-subscribe on error so watcher continues monitoring
      _boltzRepo.subscribeToSwaps([swap.id]);
      rethrow;
    }
  }

  Future<void> _refundChainBitcoinToLiquid({required ChainSwap swap}) async {
    try {
      if (swap.refundTxid != null) {
        return;
      }
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

      // Unsubscribe BEFORE refunding to prevent race condition with WebSocket updates
      _boltzRepo.unsubscribeFromSwaps([swap.id]);

      String refundTxid;
      int actualFeesUsed;
      log.fine(
        '{"swapId": "${swap.id}", "function": "_processChainBitcoinToLiquidRefund", "action": "coop_refund_started", "timestamp": "${DateTime.now().toIso8601String()}"}',
      );
      try {
        actualFeesUsed = absoluteFeeOptions.fastest.value.toInt();
        refundTxid = await _boltzRepo.refundBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: actualFeesUsed,
          bitcoinRefundAddress: refundAddress,
        );
      } catch (e, st) {
        log.severe(
          message:
              '"Coop refund failed. Attempting script path spend", "action": "coop_refund_failed_fallback_script", "timestamp": "${DateTime.now().toIso8601String()}"}',
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
      log.severe(error: e, trace: st);

      // Check if transaction actually succeeded despite the error
      final recovered = await _checkAndRecoverFromOutspend(
        swap: swap,
        error: e,
        functionName: '_processChainBitcoinToLiquidRefund',
        isClaim: false,
      );
      if (recovered) return;

      // Re-subscribe on error so watcher continues monitoring
      _boltzRepo.subscribeToSwaps([swap.id]);
      rethrow;
    }
  }

  /// Helper method to check if a claim/refund transaction succeeded despite errors
  /// Returns true if the transaction was found and the swap was updated
  Future<bool> _checkAndRecoverFromOutspend({
    required Swap swap,
    required Object error,
    required String functionName,
    required bool isClaim,
  }) async {
    final errorStr = error.toString();
    if (!errorStr.contains('bad-txns-inputs-missingorspent') &&
        !errorStr.contains('txn-mempool-conflict')) {
      return false;
    }

    log.fine('{"swapId": "${swap.id}", "action": "checking_lockup_outspend"}');

    try {
      // Determine network based on swap type
      final Network network;
      final SwapDirection? swapDirection;

      if (swap is ChainSwap) {
        if (swap.type == SwapType.liquidToBitcoin) {
          // Liquid → Bitcoin: claim on Bitcoin, refund on Liquid
          network = Network.fromEnvironment(
            isTestnet: swap.environment.isTestnet,
            isLiquid: isClaim ? false : true,
          );
          swapDirection = isClaim
              ? SwapDirection.liquidToBitcoin
              : SwapDirection.liquidToBitcoin;
        } else {
          // Bitcoin → Liquid: claim on Liquid, refund on Bitcoin
          network = Network.fromEnvironment(
            isTestnet: swap.environment.isTestnet,
            isLiquid: isClaim ? true : false,
          );
          swapDirection = isClaim
              ? SwapDirection.bitcoinToLiquid
              : SwapDirection.bitcoinToLiquid;
        }
      } else if (swap is LnReceiveSwap) {
        // Lightning → Bitcoin/Liquid: only claims
        network = Network.fromEnvironment(
          isTestnet: swap.environment.isTestnet,
          isLiquid: swap.type == SwapType.lightningToLiquid,
        );
        swapDirection = null;
      } else if (swap is LnSendSwap) {
        // Bitcoin/Liquid → Lightning: only refunds
        network = Network.fromEnvironment(
          isTestnet: swap.environment.isTestnet,
          isLiquid: swap.type == SwapType.liquidToLightning,
        );
        swapDirection = null;
      } else {
        return false;
      }

      final outspendStatus = await _boltzRepo.checkSwapLockupOutspend(
        swapId: swap.id,
        swapType: swap.type,
        network: network,
        swapDirection: swapDirection,
      );

      if (outspendStatus.txid != null) {
        log.fine(
          '{"swapId": "${swap.id}", "action": "outspend_found", "txid": "${outspendStatus.txid}"}',
        );

        // Update swap based on type and whether it's a claim or refund
        final Swap updatedSwap;
        if (swap is ChainSwap) {
          if (isClaim) {
            updatedSwap = swap.copyWith(
              receiveTxid: outspendStatus.txid!,
              status: SwapStatus.completed,
              completionTime: outspendStatus.timestamp ?? DateTime.now(),
              fees: swap.fees?.copyWith(claimFee: swap.fees!.claimFee),
            );
          } else {
            updatedSwap = swap.copyWith(
              refundTxid: outspendStatus.txid!,
              status: SwapStatus.completed,
              completionTime: outspendStatus.timestamp ?? DateTime.now(),
              fees: swap.fees?.copyWith(claimFee: swap.fees!.claimFee),
            );
          }
        } else if (swap is LnReceiveSwap) {
          updatedSwap = swap.copyWith(
            receiveTxid: outspendStatus.txid!,
            status: SwapStatus.completed,
            completionTime: outspendStatus.timestamp ?? DateTime.now(),
            fees: swap.fees?.copyWith(claimFee: swap.fees!.claimFee),
          );
        } else if (swap is LnSendSwap) {
          updatedSwap = swap.copyWith(
            refundTxid: outspendStatus.txid!,
            status: SwapStatus.completed,
            completionTime: outspendStatus.timestamp ?? DateTime.now(),
            fees: swap.fees?.copyWith(claimFee: swap.fees!.claimFee),
          );
        } else {
          return false;
        }

        await _boltzRepo.updateSwap(swap: updatedSwap);
        _boltzRepo.unsubscribeFromSwaps([swap.id]);
        return true;
      }
    } catch (outspendError, outspendSt) {
      log.severe(
        message: '{"swapId": "${swap.id}", "action": "outspend_check_failed"}',
        error: outspendError,
        trace: outspendSt,
      );
    }

    return false;
  }

  Future<void> _processCompletedSwap({required Swap swap}) async {
    try {
      log.fine(
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
          return;
        case SwapType.liquidToBitcoin:
        case SwapType.bitcoinToLiquid:
          return;
      }
    } catch (e, st) {
      log.severe(error: e, trace: st);
      rethrow;
    }
  }
}
