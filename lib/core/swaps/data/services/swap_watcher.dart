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

        case SwapStatus.pending:
        case SwapStatus.paid:
        case SwapStatus.completed:
        case SwapStatus.expired:
        case SwapStatus.failed:
          return;
      }
      // ignore: empty_catches
    } catch (e) {}
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
      final address = await _walletAddressRepository.getNewReceiveAddress(
        walletId: swap.sendWalletId,
      );

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
      try {
        refundTxid = await _boltzRepo.refundBitcoinToLightningSwap(
          swapId: swap.id,
          bitcoinAddress: address.address,
          absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop refund failed. Attempting script path spend"}',
          error: e,
          trace: st,
        );
        refundTxid = await _boltzRepo.refundBitcoinToLightningSwap(
          swapId: swap.id,
          bitcoinAddress: address.address,
          absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
          cooperate: false,
        );
      }
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: address.address,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
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
      try {
        claimTxId = await _boltzRepo.claimLightningToLiquidSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          liquidAddress: receiveAddress,
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop claim failed. Attempting script path spend"}',
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
      final address = await _walletAddressRepository.getNewReceiveAddress(
        walletId: swap.sendWalletId,
      );
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
      try {
        refundTxid = await _boltzRepo.refundLiquidToLightningSwap(
          swapId: swap.id,
          liquidAddress: address.address,
          absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop refund failed. Attempting script path spend"}',
          error: e,
          trace: st,
        );
        refundTxid = await _boltzRepo.refundLiquidToLightningSwap(
          swapId: swap.id,
          liquidAddress: address.address,
          absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
          cooperate: false,
        );
      }
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: address.address,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
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
    try {
      await _boltzRepo.coopSignBitcoinToLightningSwap(swapId: swap.id);
    } catch (e, st) {
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processSendBitcoinToLnCoopSign"}',
        error: e,
        trace: st,
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
      log.severe(
        '{"swapId": "${swap.id}", "function": "_processSendLiquidToLnCoopSign"}',
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
        final claimAddress = await _walletAddressRepository
            .getNewReceiveAddress(walletId: swap.receiveWalletId!);
        finalClaimAddress = claimAddress.address;
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
      try {
        claimTxid = await _boltzRepo.claimLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          bitcoinClaimAddress: finalClaimAddress,
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop claim failed. Attempting script path spend"}',
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
      final refundAddress = await _walletAddressRepository.getNewReceiveAddress(
        walletId: swap.sendWalletId,
      );
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
      String refundTxid;
      try {
        refundTxid = await _boltzRepo.refundBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
          bitcoinRefundAddress: refundAddress.address,
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop refund failed. Attempting script path spend"}',
          error: e,
          trace: st,
        );
        refundTxid = await _boltzRepo.refundBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
          bitcoinRefundAddress: refundAddress.address,
          cooperate: false,
        );
      }
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: refundAddress.address,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
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
        final claimAddress = await _walletAddressRepository
            .getNewReceiveAddress(walletId: swap.receiveWalletId!);
        finalClaimAddress = claimAddress.address;
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
      try {
        claimTxid = await _boltzRepo.claimBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: swap.fees!.claimFee!,
          liquidClaimAddress: finalClaimAddress,
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop claim failed. Attempting script path spend"}',
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
      final refundAddress = await _walletAddressRepository.getNewReceiveAddress(
        walletId: swap.sendWalletId,
      );
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
      String refundTxid;
      try {
        refundTxid = await _boltzRepo.refundLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
          liquidRefundAddress: refundAddress.address,
          cooperate: false,
        );
      } catch (e, st) {
        log.severe(
          '{"swapId": "${swap.id}", "state": "Coop refund failed. Attempting script path spend"}',
          error: e,
          trace: st,
        );
        refundTxid = await _boltzRepo.refundLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: absoluteFeeOptions.fastest.value.toInt(),
          liquidRefundAddress: refundAddress.address,
          cooperate: false,
        );
      }
      final updatedSwap = swap.copyWith(
        refundTxid: refundTxid,
        refundAddress: refundAddress.address,
        status: SwapStatus.completed,
        completionTime: DateTime.now(),
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
}
