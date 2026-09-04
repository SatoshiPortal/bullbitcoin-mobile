import 'dart:math';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bull_sdk/boltz.dart' as boltz;

/// Broadcasts the refund of a rescued swap and settles it, or — when the
/// broadcast fails because the lockup is already spent — verifies on-chain
/// who spent it before settling.
///
/// This is the refund driver the rescue flow lost when the legacy Boltz
/// watcher was removed: `rescueSwap` stores the swap as `refundable`, and
/// without this nothing ever moves the locked funds. Ported from the
/// watcher's `_refundChain`/`_refundLnSend` (cooperative first, script path
/// on failure, live fees floored at relay minimum), plus the
/// destination-verified outspend recovery: an already-spent lockup only
/// settles the swap when the spending tx is in OUR wallet — Boltz refunding
/// its own expired lockup looks identical to a generic outspend check and
/// must never be recorded as our refund.
class RefundRescuedSwapUsecase {
  final BoltzSwapRepository _swapRepository;
  final WalletAddressRepository _walletAddressRepository;
  final WalletTransactionRepository _walletTransactionRepository;
  final FeesRepository _feesRepository;
  final ElectrumServersPort _electrumServersPort;

  RefundRescuedSwapUsecase({
    required this._swapRepository,
    required this._walletAddressRepository,
    required this._walletTransactionRepository,
    required this._feesRepository,
    required this._electrumServersPort,
  });

  /// Drives the refund of every locally-stored refundable swap that has no
  /// refund recorded yet. This is the Boltz-independent entry point: it
  /// reads only local storage, so a wedged swap reopened by the startup
  /// verification gets its refund attempted even when the Boltz API (and
  /// with it the whole restore/rescue flow) is unreachable. Never throws —
  /// per-swap failures are logged and the swap stays refundable for the
  /// next launch.
  Future<void> executeAllRefundable() async {
    try {
      final swaps = await _swapRepository.getAllSwaps();
      final refundable = [
        for (final swap in swaps)
          if (swap.status == SwapStatus.refundable)
            if (switch (swap) {
              ChainSwap() => swap.refundTxid == null,
              LnSendSwap() => swap.refundTxid == null,
              LnReceiveSwap() => false,
            })
              swap,
      ];
      if (refundable.isEmpty) {
        log.fine('SWAP_RESCUE: no locally refundable swaps to drive');
        return;
      }
      log.fine(
        'SWAP_RESCUE: driving ${refundable.length} locally refundable '
        'swap(s): ${refundable.map((s) => s.id).join(',')}',
      );
      for (final swap in refundable) {
        try {
          await execute(swap);
        } catch (e) {
          log.warning(
            'SWAP_RESCUE: local refund drive failed for ${swap.id} '
            '(stays refundable, retried next launch): $e',
          );
        }
      }
      await log.flush();
    } catch (e) {
      log.warning('SWAP_RESCUE: local refund sweep failed: $e');
    }
  }

  /// Returns the refund txid (freshly broadcast, or recovered from an
  /// already-spent lockup verified as ours). Throws [RefundRescuedSwapException]
  /// when no refund could be made; the swap then stays `refundable` so the
  /// rescue can be retried.
  Future<String> execute(Swap swap) async {
    final refundTxid = switch (swap) {
      ChainSwap() => swap.refundTxid,
      LnSendSwap() => swap.refundTxid,
      LnReceiveSwap() => throw RefundRescuedSwapException(
        'reverse swap ${swap.id} is claimed, never refunded',
      ),
    };
    if (refundTxid != null) {
      log.fine(
        'SWAP_RESCUE: ${swap.id} already has refundTxid=$refundTxid — '
        'nothing to do',
      );
      return refundTxid;
    }

    final isLiquid = switch (swap.type) {
      SwapType.liquidToBitcoin || SwapType.liquidToLightning => true,
      SwapType.bitcoinToLiquid || SwapType.bitcoinToLightning => false,
      _ => throw RefundRescuedSwapException(
        'swap ${swap.id} type ${swap.type.name} has no refund path',
      ),
    };

    log.fine(
      'SWAP_RESCUE: refunding ${swap.id} type=${swap.type.name} '
      'status=${swap.status.name} refundOnLiquid=$isLiquid',
    );

    try {
      final refundAddress = await _resolveRefundAddress(swap);
      log.fine('SWAP_RESCUE: ${swap.id} refund address $refundAddress');

      // The swap object carries the electrum URL it was created with, which
      // can be long dead by rescue time (the target user's stored server
      // times out while another configured server answers). For chain swaps
      // run the attempt through the electrum fallback port so every
      // configured server is tried — the port also owns the privacy rule
      // that a custom server never silently falls back to defaults.
      final (txid, absoluteFees) = swap is ChainSwap
          ? await _electrumServersPort.runWithFallback(
              network: ElectrumServerNetwork.fromEnvironment(
                isTestnet: swap.environment.isTestnet,
                isLiquid: isLiquid,
              ),
              operation: (connection) => _attemptRefund(
                swap,
                refundAddress: refundAddress,
                isLiquid: isLiquid,
                electrum: connection,
              ),
              isTransient: _isServerFailure,
            )
          : await _attemptRefund(
              swap,
              refundAddress: refundAddress,
              isLiquid: isLiquid,
              electrum: null,
            );

      await _swapRepository.updateSwapFields(
        swap.id,
        status: SwapStatus.refunded,
        refundTxid: txid,
        refundAddress: refundAddress,
        refundFee: absoluteFees,
        completionTime: DateTime.now(),
      );
      log.fine(
        'SWAP_RESCUE: refund succeeded for ${swap.id} txid=$txid '
        'fees=$absoluteFees',
      );
      await log.flush();
      return txid;
    } catch (e, st) {
      log.severe(
        message:
            'SWAP_RESCUE: refund failed for ${swap.id}: '
            '${_errorMessage(e)}',
        error: e,
        trace: st,
      );
      // A non-final rejection means the timelock has not passed — no refund
      // of ours can possibly be on-chain, so skip the outspend recovery: it
      // could only ever match an unrelated spend (e.g. of the lockup tx's
      // change output) and must not get the chance to mis-settle.
      if (_isNonFinalError(e)) {
        await log.flush();
        throw RefundRescuedSwapException(
          'refund for ${swap.id} is not yet final (timelock has not passed); '
          'try again later',
        );
      }
      final recovered = await _recoverFromVerifiedOutspend(swap);
      await log.flush();
      if (recovered != null) return recovered;
      throw RefundRescuedSwapException(
        'refund failed for ${swap.id}: ${_errorMessage(e)}',
      );
    }
  }

  /// One full refund attempt against one electrum server (or the swap's
  /// stored server when [electrum] is null): cooperative first, script path
  /// on any failure. The cooperative leg — sizing included — must be allowed
  /// to fail without failing the attempt: cooperation needs the Boltz API,
  /// and this path has to work with Boltz down. The script path is
  /// Boltz-free end to end (lockup UTXO from electrum, local signature,
  /// electrum broadcast).
  Future<(String, int)> _attemptRefund(
    Swap swap, {
    required String refundAddress,
    required bool isLiquid,
    required ElectrumConnection? electrum,
  }) async {
    var absoluteFees = 0;
    try {
      final txSize = await _swapRepository.getSwapRefundTxSize(
        swapId: swap.id,
        swapType: swap.type,
        refundAddressForChainSwaps: swap is ChainSwap ? refundAddress : null,
        electrum: electrum,
      );
      absoluteFees = await _refundFees(
        txSize: txSize,
        isLiquid: isLiquid,
        isTestnet: swap.environment.isTestnet,
      );
      log.fine(
        'SWAP_RESCUE: ${swap.id} cooperative refund txSize=$txSize '
        'fees=$absoluteFees server=${electrum?.url ?? 'swap-stored'}',
      );
      final txid = await _broadcastRefund(
        swap,
        refundAddress: refundAddress,
        absoluteFees: absoluteFees,
        cooperate: true,
        electrum: electrum,
      );
      return (txid, absoluteFees);
    } catch (e, st) {
      log.severe(
        message:
            'SWAP_RESCUE: cooperative refund failed for ${swap.id} '
            '(${_errorMessage(e)}); trying script path (Boltz-free)',
        error: e,
        trace: st,
      );
      final scriptPathTxSize = await _swapRepository.getSwapRefundTxSize(
        swapId: swap.id,
        swapType: swap.type,
        isCooperative: false,
        refundAddressForChainSwaps: swap is ChainSwap ? refundAddress : null,
        electrum: electrum,
      );
      absoluteFees = await _refundFees(
        txSize: scriptPathTxSize,
        isLiquid: isLiquid,
        isTestnet: swap.environment.isTestnet,
      );
      log.fine(
        'SWAP_RESCUE: ${swap.id} script-path refund '
        'txSize=$scriptPathTxSize fees=$absoluteFees '
        'server=${electrum?.url ?? 'swap-stored'}',
      );
      final txid = await _broadcastRefund(
        swap,
        refundAddress: refundAddress,
        absoluteFees: absoluteFees,
        cooperate: false,
        electrum: electrum,
      );
      return (txid, absoluteFees);
    }
  }

  /// Whether an attempt failed because the SERVER was unreachable (worth
  /// trying the next configured server) as opposed to the refund itself
  /// being invalid (timelock, already spent — no server can change that).
  bool _isServerFailure(Object error) {
    final message = _errorMessage(error).toLowerCase();
    if (_isNonFinalError(error)) return false;
    if (message.contains('missingorspent')) return false;
    return message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('connection') ||
        message.contains('refused') ||
        message.contains('lookup') ||
        message.contains('electrum') ||
        message.contains('socket');
  }

  Future<String> _broadcastRefund(
    Swap swap, {
    required String refundAddress,
    required int absoluteFees,
    required bool cooperate,
    required ElectrumConnection? electrum,
  }) {
    switch (swap.type) {
      case SwapType.liquidToBitcoin:
        return _swapRepository.refundLiquidToBitcoinSwap(
          swapId: swap.id,
          liquidRefundAddress: refundAddress,
          absoluteFees: absoluteFees,
          cooperate: cooperate,
          electrum: electrum,
        );
      case SwapType.bitcoinToLiquid:
        return _swapRepository.refundBitcoinToLiquidSwap(
          swapId: swap.id,
          bitcoinRefundAddress: refundAddress,
          absoluteFees: absoluteFees,
          cooperate: cooperate,
          electrum: electrum,
        );
      case SwapType.liquidToLightning:
        return _swapRepository.refundLiquidToLightningSwap(
          swapId: swap.id,
          liquidAddress: refundAddress,
          absoluteFees: absoluteFees,
          cooperate: cooperate,
        );
      case SwapType.bitcoinToLightning:
        return _swapRepository.refundBitcoinToLightningSwap(
          swapId: swap.id,
          bitcoinAddress: refundAddress,
          absoluteFees: absoluteFees,
          cooperate: cooperate,
        );
      case SwapType.lightningToBitcoin:
      case SwapType.lightningToLiquid:
        throw RefundRescuedSwapException(
          'reverse swap ${swap.id} has no refund transaction',
        );
    }
  }

  /// After a failed broadcast, checks whether the lockup is already spent
  /// and — only when the spending tx is in the wallet the refund pays into —
  /// settles the swap on it. Spends by anyone else (Boltz refunding its own
  /// lockup) are logged and ignored: the swap stays refundable.
  Future<String?> _recoverFromVerifiedOutspend(Swap swap) async {
    try {
      final Network network;
      SwapDirection? swapDirection;
      switch (swap) {
        case ChainSwap():
          network = Network.fromEnvironment(
            isTestnet: swap.environment.isTestnet,
            isLiquid: swap.type == SwapType.liquidToBitcoin,
          );
          swapDirection = swap.type == SwapType.liquidToBitcoin
              ? SwapDirection.liquidToBitcoin
              : SwapDirection.bitcoinToLiquid;
        case LnSendSwap():
          network = Network.fromEnvironment(
            isTestnet: swap.environment.isTestnet,
            isLiquid: swap.type == SwapType.liquidToLightning,
          );
        case LnReceiveSwap():
          return null;
      }

      final outspends = await _swapRepository.checkLockupOutspends(
        swapId: swap.id,
        swapType: swap.type,
        network: network,
        swapDirection: swapDirection,
        isClaim: false,
      );
      if (outspends.isEmpty) {
        log.fine(
          'SWAP_RESCUE: ${swap.id} lockup outputs all unspent — funds still '
          'locked, swap stays refundable',
        );
        return null;
      }

      final sendWalletId = switch (swap) {
        ChainSwap() => swap.sendWalletId,
        LnSendSwap() => swap.sendWalletId,
        LnReceiveSwap() => null,
      };
      // The outspend report covers EVERY vout of the lockup tx — including
      // the wallet's own change output, whose later spend (an ordinary send
      // or consolidation) is also "in our wallet". Only an INCOMING wallet
      // tx can be our refund (it spends the external covenant and pays the
      // wallet); an outgoing/self spend is the change moving and must never
      // settle the swap. Fail closed on anything else.
      SwapTxOutspend? ours;
      for (final candidate in outspends) {
        final txid = candidate.txid;
        if (txid == null || sendWalletId == null) continue;
        final tx = await _walletTransactionRepository.getWalletTransaction(
          txid,
          walletId: sendWalletId,
        );
        if (tx == null) continue;
        if (!tx.isIncoming) {
          log.fine(
            'SWAP_RESCUE: ${swap.id} lockup output spent by $txid which is '
            'in our wallet but not incoming (change/self spend, not a '
            'refund) — ignoring',
          );
          continue;
        }
        ours = candidate;
        break;
      }
      if (ours == null) {
        log.warning(
          'SWAP_RESCUE: ${swap.id} lockup outputs spent by '
          '${outspends.map((o) => o.txid).whereType<String>().join(',')} '
          'but none is an incoming tx of our wallet — NOT settling (spender '
          'is Boltz or our own change moving, not our refund); swap stays '
          'refundable',
        );
        return null;
      }

      final txid = ours.txid!;
      log.fine(
        'SWAP_RESCUE: ${swap.id} refund already on-chain as $txid '
        '(verified in wallet) — settling',
      );
      await _swapRepository.updateSwapFields(
        swap.id,
        status: SwapStatus.refunded,
        refundTxid: txid,
        completionTime: ours.timestamp ?? DateTime.now(),
      );
      return txid;
    } catch (e, st) {
      log.severe(
        message: 'SWAP_RESCUE: outspend check failed for ${swap.id}',
        error: e,
        trace: st,
      );
      return null;
    }
  }

  Future<String> _resolveRefundAddress(Swap swap) async {
    final (existing, sendWalletId) = switch (swap) {
      ChainSwap() => (swap.refundAddress, swap.sendWalletId),
      LnSendSwap() => (swap.refundAddress, swap.sendWalletId),
      LnReceiveSwap() => (null, null),
    };
    if (existing != null) return existing;
    if (sendWalletId == null) {
      throw RefundRescuedSwapException(
        'swap ${swap.id} has no wallet to refund into',
      );
    }
    final address = await _walletAddressRepository.generateNewReceiveAddress(
      walletId: sendWalletId,
    );
    await _swapRepository.updateSwapFields(
      swap.id,
      refundAddress: address.address,
    );
    return address.address;
  }

  /// Live network fee for [txSize], floored at the relay minimum. When the
  /// fee API is unreachable (this path must work with every Bull/Boltz
  /// service down, electrum alone standing), falls back to the relay-floor
  /// fee itself: always broadcastable, and on Liquid the floor is the normal
  /// rate anyway.
  Future<int> _refundFees({
    required int txSize,
    required bool isLiquid,
    required bool isTestnet,
  }) async {
    try {
      final networkFee = await _feesRepository.getNetworkFees(
        network: Network.fromEnvironment(
          isTestnet: isTestnet,
          isLiquid: isLiquid,
        ),
      );
      return _absoluteWithFloor(
        networkFee.toAbsolute(txSize).fastest.value.toInt(),
        txSize: txSize,
        isLiquid: isLiquid,
      );
    } catch (e) {
      final floor = _relayFloor(txSize: txSize, isLiquid: isLiquid);
      log.warning(
        'SWAP_RESCUE: fee estimation unavailable ($e) — falling back to the '
        'relay-floor fee of $floor sats for txSize=$txSize',
      );
      return floor;
    }
  }

  /// Floors an absolute fee at the network's relay minimum so a low estimate
  /// can never produce an unbroadcastable transaction. Liquid floors at
  /// 0.1 sat/vb (plus discount-CT padding), Bitcoin at 1 sat/vb.
  int _absoluteWithFloor(
    int absolute, {
    required int txSize,
    required bool isLiquid,
  }) => max(absolute, _relayFloor(txSize: txSize, isLiquid: isLiquid));

  int _relayFloor({required int txSize, required bool isLiquid}) =>
      isLiquid ? (txSize * 0.11).ceil() + 1 : txSize;

  bool _isNonFinalError(Object error) {
    final message = _errorMessage(error).toLowerCase();
    return message.contains('non-final') ||
        message.contains('non_final') ||
        message.contains('nonfinal') ||
        message.contains('non-bip68-final') ||
        message.contains('locktime');
  }

  String _errorMessage(Object error) {
    if (error is boltz.BoltzError) {
      return error.message;
    }
    return error.toString();
  }
}

class RefundRescuedSwapException extends BullException {
  RefundRescuedSwapException(super.message);
}
