import 'dart:async';

import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/logging/domain/repositories/log_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_address_repository.dart';
import 'package:flutter/foundation.dart';

class SwapWatcherServiceImpl implements SwapWatcherService {
  final BoltzSwapRepositoryImpl _boltzRepo;
  final WalletAddressRepository _walletAddressRepository;
  final FeesRepository _feesRepository;
  final SettingsRepository _settingsRepository;
  final LogRepository _logRepository;

  final StreamController<Swap> _swapStreamController =
      StreamController<Swap>.broadcast();
  StreamSubscription<Swap>? _swapStreamSubscription;
  SwapWatcherServiceImpl({
    required BoltzSwapRepositoryImpl boltzRepo,
    required WalletAddressRepository walletAddressRepository,
    required FeesRepository feesRepository,
    required SettingsRepository settingsRepository,
    required LogRepository logRepository,
  }) : _boltzRepo = boltzRepo,
       _walletAddressRepository = walletAddressRepository,
       _feesRepository = feesRepository,
       _settingsRepository = settingsRepository,
       _logRepository = logRepository {
    startWatching();
  }
  @override
  Stream<Swap> get swapStream => _swapStreamController.stream;

  void startWatching() {
    _swapStreamSubscription = _boltzRepo.swapUpdatesStream.listen(
      (swap) async {
        await _logRepository.logInfo(
          message: 'Received Swap Update',
          logger: 'SwapWatcherService',
          context: {
            'swapId': swap.id,
            'status': swap.status.name,
            'function': 'startWatching',
          },
        );
        // Notify the rest of the app about the swap update before processing it
        // which changes the status of the swap again
        _swapStreamController.add(swap);
        await _processSwap(swap);
      },
      onError: (error) {
        debugPrint('Swap stream error in watcher: $error');
      },
      onDone: () {
        debugPrint('Swap stream done in watcher.');
      },
      cancelOnError: false,
    );

    debugPrint('Swap watcher started and listening');
  }

  @override
  Future<void> restartWatcherWithOngoingSwaps() async {
    await _swapStreamSubscription?.cancel();

    final swaps = await _boltzRepo.getOngoingSwaps();
    final swapIdsToWatch = swaps.map((swap) => swap.id).toList();
    if (swapIdsToWatch.isNotEmpty) {
      await _logRepository.logInfo(
        message: 'Watching Swaps',
        logger: 'SwapWatcherService',
        context: {
          'swapIds': swapIdsToWatch.join(', '),
          'function': 'restartWatcherWithOngoingSwaps',
        },
      );
    }
    await _boltzRepo.reinitializeStreamWithSwaps(swapIds: swapIdsToWatch);
    startWatching();
  }

  Future<void> _processSwap(Swap swap) async {
    switch (swap.status) {
      case SwapStatus.claimable:
        switch (swap.type) {
          case SwapType.lightningToBitcoin:
            await _processReceiveLnToBitcoinClaim(swap: swap as LnReceiveSwap);
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

      case SwapStatus.pending:
      case SwapStatus.paid:
      case SwapStatus.completed:
      case SwapStatus.expired:
      case SwapStatus.failed:
        // No processing needed for these statuses anymore
        return;
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
      final claimTxId = await _boltzRepo.claimLightningToBitcoinSwap(
        swapId: swap.id,
        absoluteFees: swap.fees!.claimFee!,
        bitcoinAddress: swap.receiveAddress!,
      );
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxId,
        receiveAddress: swap.receiveAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      await _logRepository.logError(
        message: e.toString(),
        logger: 'SwapWatcherService',
        exception: e,
        stackTrace: st,
        context: {
          'swapId': swap.id,
          'function': '_processReceiveLnToBitcoinClaim',
        },
      );
      rethrow;
    }
  }

  Future<void> _processSendBitcoinToLnRefund({required LnSendSwap swap}) async {
    try {
      final address = await _walletAddressRepository.getNewAddress(
        walletId: swap.sendWalletId,
      );
      if (!address.isBitcoin) {
        throw Exception('Refund Address is not a Bitcoin address');
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
      final refundTxid = await _boltzRepo.refundBitcoinToLightningSwap(
        swapId: swap.id,
        bitcoinAddress: address.address,
        absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
      );
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: address.address,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      await _logRepository.logError(
        message: e.toString(),
        logger: 'SwapWatcherService',
        exception: e,
        stackTrace: st,
        context: {
          'swapId': swap.id,
          'function': '_processSendBitcoinToLnRefund',
        },
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
      final claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
        swapId: swap.id,
        absoluteFees: swap.fees!.claimFee!,
        liquidAddress: receiveAddress,
      );
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxId,
        receiveAddress: receiveAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      await _logRepository.logError(
        message: e.toString(),
        logger: 'SwapWatcherService',
        exception: e,
        stackTrace: st,
        context: {
          'swapId': swap.id,
          'function': '_processReceiveLnToLiquidClaim',
        },
      );
      rethrow;
    }
  }

  Future<void> _processSendLiquidToLnRefund({required LnSendSwap swap}) async {
    try {
      final address = await _walletAddressRepository.getNewAddress(
        walletId: swap.sendWalletId,
      );
      if (!address.isLiquid) {
        throw Exception('Refund Address is not a Liquid address');
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
      final refundTxid = await _boltzRepo.refundLiquidToLightningSwap(
        swapId: swap.id,
        liquidAddress: address.address,
        absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
      );
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: address.address,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      await _logRepository.logError(
        message: e.toString(),
        logger: 'SwapWatcherService',
        exception: e,
        stackTrace: st,
        context: {
          'swapId': swap.id,
          'function': '_processSendLiquidToLnRefund',
        },
      );
      rethrow;
    }
  }

  Future<void> _processSendBitcoinToLnCoopSign({
    required LnSendSwap swap,
  }) async {
    try {
      await _boltzRepo.coopSignBitcoinToLightningSwap(swapId: swap.id);
    } catch (e, st) {
      await _logRepository.logError(
        message: e.toString(),
        logger: 'SwapWatcherService',
        exception: e,
        stackTrace: st,
        context: {
          'swapId': swap.id,
          'function': '_processSendBitcoinToLnCoopSign',
        },
      );
      rethrow;
    }
  }

  Future<void> _processSendLiquidToLnCoopSign({
    required LnSendSwap swap,
  }) async {
    try {
      final isBatched = swap.paymentAmount < 1000;
      if (isBatched) {
        final updatedSwap = swap.copyWith(
          status: SwapStatus.completed,
          completionTime: DateTime.now(),
        );
        await _boltzRepo.updateSwap(swap: updatedSwap);
      } else {
        await _boltzRepo.coopSignLiquidToLightningSwap(swapId: swap.id);
      }
    } catch (e, st) {
      await _logRepository.logError(
        message: e.toString(),
        logger: 'SwapWatcherService',
        exception: e,
        stackTrace: st,
        context: {
          'swapId': swap.id,
          'function': '_processSendLiquidToLnCoopSign',
        },
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
        final claimAddress = await _walletAddressRepository.getNewAddress(
          walletId: swap.receiveWalletId!,
        );
        if (!claimAddress.isBitcoin) {
          throw Exception('Claim address is not a Bitcoin address');
        }
        finalClaimAddress = claimAddress.address;
      } else {
        finalClaimAddress = swap.receiveAddress!;
      }
      final refundAddress = await _walletAddressRepository.getNewAddress(
        walletId: swap.sendWalletId,
      );
      if (!refundAddress.isLiquid) {
        throw Exception('Refund address is not a Liquid address');
      }
      final claimTxid = await _boltzRepo.claimLiquidToBitcoinSwap(
        swapId: swap.id,
        absoluteFees: swap.fees!.claimFee!,
        bitcoinClaimAddress: finalClaimAddress,
        liquidRefundAddress: refundAddress.address,
      );
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxid,
        receiveAddress: finalClaimAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      await _logRepository.logError(
        message: e.toString(),
        logger: 'SwapWatcherService',
        exception: e,
        stackTrace: st,
        context: {
          'swapId': swap.id,
          'function': '_processChainLiquidToBitcoinClaim',
        },
      );
      rethrow;
    }
  }

  Future<void> _processChainBitcoinToLiquidRefund({
    required ChainSwap swap,
  }) async {
    try {
      final refundAddress = await _walletAddressRepository.getNewAddress(
        walletId: swap.sendWalletId,
      );
      if (!refundAddress.isBitcoin) {
        throw Exception('Refund address is not a Bitcoin address');
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
        refundAddressForChainSwaps: refundAddress.address,
      );
      final absoluteFeeOptions = networkFee.toAbsolute(txSize);
      final refundTxid = await _boltzRepo.refundBitcoinToLiquidSwap(
        swapId: swap.id,
        absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
        bitcoinRefundAddress: refundAddress.address,
      );
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: refundAddress.address,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      await _logRepository.logError(
        message: e.toString(),
        logger: 'SwapWatcherService',
        exception: e,
        stackTrace: st,
        context: {
          'swapId': swap.id,
          'function': '_processChainBitcoinToLiquidRefund',
        },
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
        final claimAddress = await _walletAddressRepository.getNewAddress(
          walletId: swap.receiveWalletId!,
        );
        if (!claimAddress.isLiquid) {
          throw Exception('Claim address is not a Liquid address');
        }
        finalClaimAddress = claimAddress.address;
      } else {
        finalClaimAddress = swap.receiveAddress!;
      }
      final refundAddress = await _walletAddressRepository.getNewAddress(
        walletId: swap.sendWalletId,
      );
      if (!refundAddress.isBitcoin) {
        throw Exception('Refund address is not a Bitcoin address');
      }
      final claimTxid = await _boltzRepo.claimBitcoinToLiquidSwap(
        swapId: swap.id,
        absoluteFees: swap.fees!.claimFee!,
        liquidClaimAddress: finalClaimAddress,
        bitcoinRefundAddress: refundAddress.address,
      );
      final updatedSwap = swap.copyWith(
        receiveTxid: claimTxid,
        receiveAddress: finalClaimAddress,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      await _logRepository.logError(
        message: e.toString(),
        logger: 'SwapWatcherService',
        exception: e,
        stackTrace: st,
        context: {
          'swapId': swap.id,
          'function': '_processChainBitcoinToLiquidClaim',
        },
      );
      rethrow;
    }
  }

  Future<void> _processChainLiquidToBitcoinRefund({
    required ChainSwap swap,
  }) async {
    try {
      final refundAddress = await _walletAddressRepository.getNewAddress(
        walletId: swap.sendWalletId,
      );
      if (!refundAddress.isLiquid) {
        throw Exception('Claim address is not a Liquid address');
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
        refundAddressForChainSwaps: refundAddress.address,
      );
      final absoluteFeeOptions = networkFee.toAbsolute(txSize);
      final refundTxid = await _boltzRepo.refundLiquidToBitcoinSwap(
        swapId: swap.id,
        absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
        liquidRefundAddress: refundAddress.address,
      );
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: refundAddress.address,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
      );
      await _boltzRepo.updateSwap(swap: updatedSwap);
    } catch (e, st) {
      await _logRepository.logError(
        message: e.toString(),
        logger: 'SwapWatcherService',
        exception: e,
        stackTrace: st,
        context: {
          'swapId': swap.id,
          'function': '_processChainLiquidToBitcoinRefund',
        },
      );
      rethrow;
    }
  }
}
