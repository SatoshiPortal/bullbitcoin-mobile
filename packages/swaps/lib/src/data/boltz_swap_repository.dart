import 'dart:async';

import 'package:swaps/src/util.dart';
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/domain/swap_repository.dart';
import 'package:swaps/src/data/models/swap_model.dart';
import 'package:swaps/src/domain/entities/restored_swap.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_master_key_info.dart';
import 'package:swaps/src/domain/entities/swap_tx_outspend.dart'
    hide SwapDirection;
import 'package:swaps/src/domain/entities/swap_tx_outspend.dart' as outspend;
import 'package:swaps/src/log.dart';
import 'package:bull_sdk/boltz.dart' as boltz;

/// Fresh receive address on [walletId], for claim/refund destinations.
typedef NewAddressFor = Future<String> Function(String walletId);

/// Look up one wallet transaction (null when absent). [sync] freshens the
/// wallet first; implementations must throw — not return stale data — when
/// freshening was requested but failed.
typedef WalletTxLookup =
    Future<SwapWalletTx?> Function(String txid, {required String walletId});

typedef WalletTxsLookup =
    Future<List<SwapWalletTx>> Function(String walletId, {bool sync});

/// Fastest-confirmation absolute fee for [txSize] vbytes; throws when the
/// estimate is unavailable (the engine falls back to the relay floor).
typedef FastestFee =
    Future<int> Function({
      required int txSize,
      required bool isLiquid,
      required bool isTestnet,
    });

typedef WalletsList =
    Future<List<SwapWalletInfo>> Function({required bool isTestnet});

/// The default bitcoin wallet's seed for deriving the swap master key; null
/// when unavailable (watch-only / hardware-only / pre-onboarding).
typedef MasterSeedSource =
    Future<SwapSeedSource?> Function({required bool isTestnet});

class BoltzSwapRepository implements SwapRepository {
  final BoltzDatasource _boltz;
  final bool _isTestnet;
  final ElectrumRunner _electrum;
  final NewAddressFor _newAddressFor;
  final WalletTxLookup _walletTx;
  final WalletTxsLookup _walletTxs;
  final FastestFee _fastestFee;
  final WalletsList _wallets;
  final MasterSeedSource _masterSeedSource;

  /// Serializes swap creation so two concurrent creations can never compute
  /// the same key index from a stale table scan.
  Future<void> _creationLock = Future.value();

  BoltzSwapRepository({
    required this._boltz,
    required this._isTestnet,
    required this._electrum,
    required this._newAddressFor,
    required this._walletTx,
    required this._walletTxs,
    required this._fastestFee,
    required this._wallets,
    required this._masterSeedSource,
  });

  Future<T> _withCreationLock<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _creationLock;
    _creationLock = completer.future;
    return previous
        .catchError((_) {})
        .then((_) => action())
        .whenComplete(completer.complete);
  }

  Stream<Swap> get swapUpdatesStream =>
      _boltz.swapUpdatesStream.map((swapModel) => swapModel.toEntity());

  /// RECEIVE LN TO BTC

  Future<LnReceiveSwap> createLightningToBitcoinSwap({
    required String walletId,
    required int amountSat,
    required String electrumUrl,
    required String claimAddress,
    String? description,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final btcLnSwap = await _boltz.createBtcReverseSwap(
        walletId: walletId,
        index: index,
        outAmount: amountSat,
        isTestnet: _isTestnet,
        electrumUrl: electrumUrl,
        magicRouteHintAddress: claimAddress,
        description: description,
      );
      return btcLnSwap.toEntity() as LnReceiveSwap;
    });
  }

  Future<String> claimLightningToBitcoinSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final txid = await _boltz.claimBtcReverseSwap(
      swapId: swapId,
      claimAddress: bitcoinAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastBtcLnSwap(
      swapId: swapId,
      signedTxHex: txid,
      broadcastViaBoltz: false,
    );
  }

  /// RECEIVE LN TO LBTC

  Future<LnReceiveSwap> createLightningToLiquidSwap({
    required String walletId,
    required int amountSat,
    required String electrumUrl,
    required String claimAddress,
    String? description,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final lbtcLnSwap = await _boltz.createLBtcReverseSwap(
        walletId: walletId,
        index: index,
        outAmount: amountSat,
        isTestnet: _isTestnet,
        electrumUrl: electrumUrl,
        magicRouteHintAddress: claimAddress,
        description: description,
      );

      return lbtcLnSwap.toEntity() as LnReceiveSwap;
    });
  }

  Future<String> claimLightningToLiquidSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.claimLBtcReverseSwap(
      swapId: swapId,
      claimAddress: liquidAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastLbtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  /// SEND BTC TO LN

  Future<LnSendSwap> createBitcoinToLightningSwap({
    required String walletId,
    required String invoice,
    required String electrumUrl,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final btcLnSwap = await _boltz.createBtcSubmarineSwap(
        walletId: walletId,
        index: index,
        invoice: invoice,
        isTestnet: _isTestnet,
        electrumUrl: electrumUrl,
      );

      return btcLnSwap.toEntity() as LnSendSwap;
    });
  }

  Future<void> coopSignBitcoinToLightningSwap({required String swapId}) async {
    await _boltz.coopSignBtcSubmarineSwap(swapId: swapId);
    await _updateCompletedSendSwap(swapId: swapId);
    return;
  }

  Future<String> refundBitcoinToLightningSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.refundBtcSubmarineSwap(
      swapId: swapId,
      refundAddress: bitcoinAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastBtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  /// SEND LBTC TO LN

  Future<LnSendSwap> createLiquidToLightningSwap({
    required String walletId,
    required String invoice,
    required String electrumUrl,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final lbtcLnSwap = await _boltz.createLbtcSubmarineSwap(
        walletId: walletId,
        index: index,
        invoice: invoice,
        isTestnet: _isTestnet,
        electrumUrl: electrumUrl,
      );

      return lbtcLnSwap.toEntity() as LnSendSwap;
    });
  }

  Future<void> coopSignLiquidToLightningSwap({required String swapId}) async {
    await _boltz.coopSignLbtcSubmarineSwap(swapId: swapId);
    await _updateCompletedSendSwap(swapId: swapId);
    return;
  }

  Future<String> refundLiquidToLightningSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.refundLbtcSubmarineSwap(
      swapId: swapId,
      refundAddress: liquidAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastLbtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  Future<ChainSwap> createBitcoinToLiquidSwap({
    required String sendWalletId,
    required int amountSat,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(2);
      final chainSwap = await _boltz.createBtcToLbtcChainSwap(
        sendWalletId: sendWalletId,
        index: index,
        amountSat: amountSat,
        isTestnet: _isTestnet,
        btcElectrumUrl: btcElectrumUrl,
        lbtcElectrumUrl: lbtcElectrumUrl,
        receiveWalletId: receiveWalletId,
        externalRecipientAddress: externalRecipientAddress,
      );

      return chainSwap.toEntity() as ChainSwap;
    });
  }

  Future<ChainSwap> createLiquidToBitcoinSwap({
    required String sendWalletId,
    required int amountSat,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(2);
      final chainSwap = await _boltz.createLbtcToBtcChainSwap(
        sendWalletId: sendWalletId,
        index: index,
        amountSat: amountSat,
        isTestnet: _isTestnet,
        btcElectrumUrl: btcElectrumUrl,
        lbtcElectrumUrl: lbtcElectrumUrl,
        receiveWalletId: receiveWalletId,
        externalRecipientAddress: externalRecipientAddress,
      );

      return chainSwap.toEntity() as ChainSwap;
    });
  }

  Future<String> claimLiquidToBitcoinSwap({
    required String swapId,
    required String bitcoinClaimAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.claimLbtcToBtcChainSwap(
      swapId: swapId,
      claimBitcoinAddress: bitcoinClaimAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastChainSwapClaim(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  Future<String> claimBitcoinToLiquidSwap({
    required String swapId,
    required String liquidClaimAddress,
    required int absoluteFees,
    bool cooperate = true,
  }) async {
    final signedTxHex = await _boltz.claimBtcToLbtcChainSwap(
      swapId: swapId,
      claimLiquidAddress: liquidClaimAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
    );

    return await _boltz.broadcastChainSwapClaim(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
    );
  }

  Future<String> refundBitcoinToLiquidSwap({
    required String swapId,
    required String bitcoinRefundAddress,
    required int absoluteFees,
    bool cooperate = true,
    ElectrumConnection? electrum,
  }) async {
    final signedTxHex = await _boltz.refundBtcToLbtcChainSwap(
      swapId: swapId,
      refundBitcoinAddress: bitcoinRefundAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
      electrum: electrum,
    );

    return await _boltz.broadcastChainSwapRefund(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
      electrum: electrum,
    );
  }

  Future<String> refundLiquidToBitcoinSwap({
    required String swapId,
    required String liquidRefundAddress,
    required int absoluteFees,
    bool cooperate = true,
    ElectrumConnection? electrum,
  }) async {
    final signedTxHex = await _boltz.refundLbtcToBtcChainSwap(
      swapId: swapId,
      refundLiquidAddress: liquidRefundAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
      electrum: electrum,
    );

    return await _boltz.broadcastChainSwapRefund(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
      electrum: electrum,
    );
  }

  // STORAGE

  Future<Swap> getSwap({required String swapId}) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap found";
    }
    return swapModel.toEntity();
  }

  /// DB-backed: emits current state on listen + every change, so observers
  /// can't miss a terminal update like the old broadcast stream could.
  Stream<Swap> watchSwap({required String swapId}) =>
      _boltz.storage.watchSwap(swapId).map((model) => model.toEntity());

  Future<void> updatePaidSendSwap({
    required String swapId,
    required String txid,
    int? absoluteFees,
  }) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    // check the status before updating it
    // it is possible that the stream updates the status before this method
    // we don't want a status ahead of paid to be updated back to paid
    final updatedSwap = switch (swap) {
      LnSendSwap() => swap.copyWith(
        sendTxid: txid,
        status: swap.status == SwapStatus.pending
            ? SwapStatus.paid
            : swap.status,
        fees: absoluteFees != null
            ? swap.fees?.copyWith(lockupFee: absoluteFees)
            : swap.fees,
      ),
      ChainSwap() => swap.copyWith(
        sendTxid: txid,
        status: swap.status == SwapStatus.pending
            ? SwapStatus.paid
            : swap.status,
        fees: absoluteFees != null
            ? swap.fees?.copyWith(lockupFee: absoluteFees)
            : swap.fees,
      ),
      _ => throw "Only lnSend or chain swaps can be marked as paid",
    };

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  Future<Swap> updateSendSwapLockupFees({
    required String swapId,
    required int lockupFees,
  }) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    final updatedSwap = switch (swap) {
      LnSendSwap() => swap.copyWith(
        fees: swap.fees?.copyWith(lockupFee: lockupFees),
      ),
      ChainSwap() => swap.copyWith(
        fees: swap.fees?.copyWith(lockupFee: lockupFees),
      ),
      _ => throw "Only lnSend or chain swaps can have lockup fees updated",
    };

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
    return updatedSwap;
  }

  /// PRIVATE
  Future<void> _updateCompletedSendSwap({required String swapId}) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    if (!(swap.status == SwapStatus.paid ||
        swap.status == SwapStatus.canCoop)) {
      throw "Can only update status of a paid or canCoop swap";
    }

    // Handle each type separately
    final updatedSwap = switch (swap) {
      LnReceiveSwap() =>
        swap.receiveTxid != null
            ? swap.copyWith(
                completionTime: DateTime.now(),
                status: SwapStatus.completed,
              )
            : swap,
      LnSendSwap() => swap.copyWith(
        completionTime: DateTime.now(),
        status: SwapStatus.completed,
      ),
      ChainSwap() =>
        (swap.receiveTxid != null || swap.refundTxid != null)
            ? swap.copyWith(
                completionTime: DateTime.now(),
                status: SwapStatus.completed,
              )
            : swap,
    };

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  /// Binds the swap master key to [walletFingerprint] for reads and reports
  /// whether it already exists — cheap, so the caller can skip decrypting the
  /// wallet seed when the key is already present.
  Future<bool> swapMasterKeyReady({required String walletFingerprint}) =>
      _boltz.swapMasterKeyReady(
        walletFingerprint: walletFingerprint,
        isTestnet: _isTestnet,
      );

  /// Derives + persists the swap master key from the default wallet's seed.
  /// Called once, only when [swapMasterKeyReady] reported a miss, so swap
  /// creation and restore can READ the key from storage and never derive lazily.
  Future<void> deriveSwapMasterKey({
    required String mnemonic,
    required String walletFingerprint,
  }) => _boltz.deriveSwapMasterKey(
    mnemonic: mnemonic,
    walletFingerprint: walletFingerprint,
    isTestnet: _isTestnet,
  );

  /// Reads the swap master key (the "swap mnemonic") for [walletFingerprint]
  /// for display/management in the seed viewer. Null when none is stored.
  Future<SwapMasterKeyInfo?> getSwapMasterKeyInfo({
    required String walletFingerprint,
  }) async {
    final model = await _boltz.getSwapMasterKeyForWallet(
      walletFingerprint: walletFingerprint,
      isTestnet: _isTestnet,
    );
    if (model == null) return null;
    return SwapMasterKeyInfo(
      mnemonic: model.mnemonic,
      fingerprint: model.fingerprint,
      walletFingerprint: walletFingerprint,
      network: model.network,
    );
  }

  /// Deletes the swap master key (and its index counter) for
  /// [walletFingerprint]. Super-user action; the next ensure re-derives it.
  Future<void> deleteSwapMasterKey({required String walletFingerprint}) =>
      _boltz.deleteSwapMasterKey(
        walletFingerprint: walletFingerprint,
        isTestnet: _isTestnet,
      );

  // Reverse and submarine swaps consume 1 index; chain swaps consume 2 (boltz
  // derives the refund key at `index` and the claim key at `index + 1`).
  Future<int> _reserveSwapKeyIndex(int count) async {
    final swapMasterKey = await _boltz.getSwapMasterKey(isTestnet: _isTestnet);
    // The index counter is keyed by the swap master key's OWN fingerprint —
    // NOT the default wallet's fingerprint (which keys the master key blob).
    // Both are 1:1 with the seed, so they stay consistent.
    final stored = await _boltz.storage.getSwapKeyIndex(
      swapMasterKey.fingerprint,
    );
    final int current;
    if (stored == null) {
      // Seed past boltz's highest known index (-1 when none) so a new swap
      // can't re-derive an in-use key on a recovered seed.
      final highest = await _boltz.restoreSwapIndex(
        swapMasterKey: swapMasterKey,
      );
      current = highest + 1;
    } else {
      current = stored;
    }
    await _boltz.storage.setSwapKeyIndex(
      swapMasterKey.fingerprint,
      current + count,
    );
    swapsLog.info(
      'SWAP_KEY: reserved index $current (count=$count) '
      'fp=${swapMasterKey.fingerprint}',
    );
    return current;
  }

  /// Removes a swap entirely — local row + secure blob. Used when a recovered
  /// swap is found to be already resolved on-chain (its lockup is already
  /// spent), so it must not keep lingering in the transaction list.
  Future<void> deleteSwap({required String swapId}) async {
    await _boltz.storage.trash(swapId);
    await _boltz.storage.deleteFromSecureStorage(swapId);
  }

  Future<void> updateSwap({required Swap swap}) {
    return _boltz.storage.store(SwapModel.fromEntity(swap));
  }

  /// Single write path for the watcher: re-fetches the stored swap and
  /// merges only the given fields, so a concurrent write (preimage, lockup
  /// fees, sendTxid) is never clobbered by a stale in-memory copy.
  Future<Swap> updateSwapFields(
    String swapId, {
    SwapStatus? status,
    String? receiveTxid,
    String? refundTxid,
    String? receiveAddress,
    String? refundAddress,
    String? preimage,
    int? claimFee,
    int? refundFee,
    DateTime? completionTime,
    // Null means "keep" for every field above, so retracting a recorded
    // claim tx (un-wedging a mis-settled swap) needs an explicit flag.
    bool clearReceiveTxid = false,
  }) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw 'No swap model found';
    }
    final swap = swapModel.toEntity();
    final fees = (swap.fees ?? const SwapFees()).copyWith(
      claimFee: claimFee ?? swap.fees?.claimFee,
      refundFee: refundFee ?? swap.fees?.refundFee,
    );

    final updated = switch (swap) {
      LnReceiveSwap() => swap.copyWith(
        status: status ?? swap.status,
        receiveTxid: clearReceiveTxid ? null : receiveTxid ?? swap.receiveTxid,
        receiveAddress: receiveAddress ?? swap.receiveAddress,
        completionTime: completionTime ?? swap.completionTime,
        fees: fees,
      ),
      LnSendSwap() => swap.copyWith(
        status: status ?? swap.status,
        refundTxid: refundTxid ?? swap.refundTxid,
        refundAddress: refundAddress ?? swap.refundAddress,
        preimage: preimage ?? swap.preimage,
        completionTime: completionTime ?? swap.completionTime,
        fees: fees,
      ),
      ChainSwap() => swap.copyWith(
        status: status ?? swap.status,
        receiveTxid: clearReceiveTxid ? null : receiveTxid ?? swap.receiveTxid,
        refundTxid: refundTxid ?? swap.refundTxid,
        receiveAddress: receiveAddress ?? swap.receiveAddress,
        refundAddress: refundAddress ?? swap.refundAddress,
        completionTime: completionTime ?? swap.completionTime,
        fees: fees,
      ),
    };

    swapsLog.fine(
      '[SwapStore] $swapId'
      '${status != null ? ' status=${swap.status.name}->${status.name}' : ''}'
      '${receiveTxid != null ? ' receiveTxid=$receiveTxid' : ''}'
      '${clearReceiveTxid ? ' receiveTxid=CLEARED(was ${swap is ChainSwap
                ? swap.receiveTxid
                : swap is LnReceiveSwap
                ? swap.receiveTxid
                : null})' : ''}'
      '${refundTxid != null ? ' refundTxid=$refundTxid' : ''}'
      '${refundFee != null ? ' refundFee=$refundFee' : ''}'
      '${completionTime != null ? ' completed' : ''}',
    );

    await _boltz.storage.store(SwapModel.fromEntity(updated));
    return updated;
  }

  Future<int> getSwapClaimTxSize({
    required String swapId,
    required SwapType swapType,
    bool isCooperative = true,
    String? claimAddressForChainSwaps,
  }) async {
    switch (swapType) {
      case SwapType.lightningToBitcoin:
        return await _boltz.getBtcLnClaimTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
        );
      case SwapType.lightningToLiquid:
        return await _boltz.getLbtcLnClaimTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
        );
      case SwapType.liquidToBitcoin:
      case SwapType.bitcoinToLiquid:
        return await _boltz.getChainClaimTxSize(
          swapId: swapId,
          claimAddress: claimAddressForChainSwaps!,
          isCooperative: isCooperative,
        );
      case SwapType.bitcoinToLightning:
      case SwapType.liquidToLightning:
        throw Exception('Submarine swaps have no claim transaction');
    }
  }

  /// Polls each swap's current status over REST and routes it through the
  /// same status pipeline as websocket events.
  Future<void> reconcileSwaps(List<String> swapIds) =>
      _boltz.reconcileSwaps(swapIds);

  /// Update claimFee to a specific value
  Future<void> updateClaimFee({
    required String swapId,
    required int claimFee,
  }) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    final updatedSwap = swap.copyWith(
      fees: swap.fees?.copyWith(claimFee: claimFee),
    );

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  /// Update lockupFee to a specific value
  Future<void> updateLockupFee({
    required String swapId,
    required int lockupFee,
  }) async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity();
    final updatedSwap = swap.copyWith(
      fees: swap.fees?.copyWith(lockupFee: lockupFee),
    );

    await _boltz.storage.store(SwapModel.fromEntity(updatedSwap));
  }

  void unsubscribeFromSwaps(List<String> swapIds) {
    _boltz.unsubscribeToSwaps(swapIds);
  }

  void subscribeToSwaps(List<String> swapIds) {
    _boltz.subscribeToSwaps(swapIds);
  }

  Future<List<Swap>> getOngoingSwaps({String? walletId}) async {
    final allSwapModels = await _boltz.storage.fetchAll(isTestnet: _isTestnet);

    final allSwaps = allSwapModels
        .map((swapModel) => swapModel.toEntity())
        .toList();
    bool needsWatching(Swap swap) {
      switch (swap.status) {
        case SwapStatus.pending:
        case SwapStatus.paid:
        case SwapStatus.canCoop:
        case SwapStatus.claimable:
        case SwapStatus.refundable:
          return true;
        case SwapStatus.completed:
          // Completed without a recorded claim tx means the claim never
          // happened (unless it was an MRH direct payment with no lockup).
          if (swap is LnReceiveSwap) {
            return swap.receiveTxid == null && !swap.wasDirectPayment;
          }
          if (swap is ChainSwap) {
            return swap.receiveTxid == null && swap.refundTxid == null;
          }
          return false;
        case SwapStatus.expired:
        case SwapStatus.failed:
          // Funds locked and never refunded: keep watching so the swap can
          // become refundable instead of stranding the funds.
          if (swap is LnSendSwap) {
            return swap.sendTxid != null && swap.refundTxid == null;
          }
          if (swap is ChainSwap) {
            return swap.sendTxid != null && swap.refundTxid == null;
          }
          return false;
        case SwapStatus.refunded:
          return false;
      }
    }

    return allSwaps
        .where(
          (swap) =>
              (walletId == null ||
                  swap.walletId == walletId ||
                  swap is ChainSwap && swap.receiveWalletId == walletId) &&
              needsWatching(swap),
        )
        .toList();
  }

  Future<List<Swap>> getAllSwaps({String? walletId}) async {
    final allSwapModels = await _boltz.storage.fetchAll(
      walletId: walletId,
      isTestnet: _isTestnet,
    );
    final allSwaps = allSwapModels
        .map((swapModel) => swapModel.toEntity())
        .toList();
    return allSwaps;
  }

  /// Restores all swaps derivable from the dedicated swap master key via Boltz,
  /// across BTC-LN, LBTC-LN and chain. Identification only (Phase 1); importing
  /// them into local storage is handled separately.
  Future<List<RestoredSwap>> restoreSwaps({required bool isTestnet}) async {
    final swapMasterKey = await _boltz.getSwapMasterKey(isTestnet: isTestnet);
    swapsLog.fine(
      'SWAP_RESTORE: master key ${swapMasterKey.fingerprint} '
      '(${swapMasterKey.network})',
    );
    final summaries = await _boltz.restoreSwapSummaries(
      swapMasterKey: swapMasterKey,
    );
    swapsLog.fine(
      'SWAP_RESTORE: restore endpoint returned ${summaries.length}',
    );
    return [
      for (final s in summaries)
        RestoredSwap(
          id: s.id,
          kind: _restoredKind(s.kind),
          status: _restoreStatusToSwapStatus(s.status),
          recoverable: _restoredRecoverable(s),
          amountSat: s.amount.toInt(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            s.createdAt.toInt() * 1000,
          ),
          fromAsset: s.from,
          toAsset: s.to,
        ),
    ];
  }

  /// boltz-dart derives `recoverable` from the raw Boltz status via
  /// `is_resolved()`, which counts `transaction.refunded` as "nothing left
  /// on-chain". That is wrong for CHAIN swaps: there it means Boltz refunded
  /// its OWN lockup — a signal for us to refund OURS, which may still sit
  /// unspent on the sending chain. Override so such swaps stay rescuable;
  /// if the user lockup turns out spent, the refund attempt learns that
  /// on-chain instead of the swap being hidden from rescue.
  bool _restoredRecoverable(boltz.RestoredSwapSummary s) {
    final overridden =
        !s.recoverable &&
        s.kind == boltz.SwapType.chain &&
        s.status == 'transaction.refunded';
    swapsLog.fine(
      'SWAP_RESTORE: summary ${s.id} kind=${s.kind.name} '
      'boltzStatus=${s.status} recoverable=${s.recoverable} '
      '${overridden ? 'OVERRIDDEN->true (chain swap: boltz refunded its own lockup; ours may be unspent) ' : ''}'
      'amount=${s.amount} from=${s.from} to=${s.to} createdAt=${s.createdAt}',
    );
    return overridden || s.recoverable;
  }

  // Submarine = on-chain → Lightning (Lightning Send); Reverse = Lightning →
  // on-chain (Lightning Receive); Chain = cross-chain.
  RestoredSwapKind _restoredKind(boltz.SwapType kind) => switch (kind) {
    boltz.SwapType.submarine => RestoredSwapKind.lightningSend,
    boltz.SwapType.reverse => RestoredSwapKind.lightningReceive,
    boltz.SwapType.chain => RestoredSwapKind.crossChain,
  };

  // Coarse mapping of the raw boltz status to the app's status for list display.
  // The rescue flow reconciles the precise per-type state (e.g. a chain
  // `transaction.claimed` where the user's own claim is still pending).
  SwapStatus _restoreStatusToSwapStatus(String boltzStatus) {
    switch (boltzStatus) {
      case 'transaction.claimed':
      case 'invoice.settled':
      case 'transaction.direct':
        return SwapStatus.completed;
      case 'swap.refunded':
      case 'transaction.refunded':
        return SwapStatus.refunded;
      case 'swap.expired':
      case 'invoice.expired':
        return SwapStatus.expired;
      case 'transaction.lockupFailed':
      case 'transaction.failed':
      case 'invoice.failedToPay':
      case 'swap.error':
        return SwapStatus.failed;
      case 'transaction.mempool':
      case 'transaction.confirmed':
      case 'transaction.server.mempool':
      case 'transaction.server.confirmed':
        return SwapStatus.claimable;
      // For a submarine swap these mean the coop-close window, not a user
      // claim — storing `claimable` wedged rescued submarine swaps in a
      // state the type can never legally hold.
      case 'transaction.claim.pending':
      case 'invoice.paid':
        return SwapStatus.canCoop;
      default:
        return SwapStatus.pending;
    }
  }

  // Whether an LN swap's on-chain leg is Liquid (vs Bitcoin). Boltz labels pure
  // BTC lightning swaps "BTC"->"BTC"; anything else involves L-BTC.
  bool _lnSwapIsLiquid(RestoredSwap r) =>
      !(r.fromAsset == 'BTC' && r.toAsset == 'BTC');

  /// Rebuilds a restored swap's full object from Boltz, persists it (secure
  /// blob + local row) under the given wallets, and hands it to the watcher so
  /// an orphaned claim/refund can be completed. [sendWalletId] funds the
  /// lockup/refund side; [receiveWalletId] receives the claim (required for
  /// reverse, optional for chain).
  Future<Swap> rescueSwap({
    required RestoredSwap restored,
    required String sendWalletId,
    String? receiveWalletId,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
  }) async {
    final swapMasterKey = await _boltz.getSwapMasterKey(isTestnet: _isTestnet);
    final creationTime = restored.createdAt.millisecondsSinceEpoch;
    // A refund-action swap with funds still locked on-chain is stored as
    // refundable (not the terminal failed/expired/refunded the restore status
    // maps to) so the watcher actually drives the refund. If the lockup turns
    // out to be already gone the refund attempt resolves it terminally.
    // Only submarine and chain swaps are user-refundable; a reverse swap is
    // claimed, never refunded, and the watcher has no refundable action for it.
    final isUserRefundable =
        restored.kind == RestoredSwapKind.lightningSend ||
        restored.kind == RestoredSwapKind.crossChain;
    final status =
        isUserRefundable && restored.recoverable && restored.isRefundAction
        ? SwapStatus.refundable.name
        : restored.status.name;
    final id = restored.id;
    final isLiquid = _lnSwapIsLiquid(restored);

    final SwapModel model;
    switch (restored.kind) {
      case RestoredSwapKind.lightningReceive:
        if (isLiquid) {
          final restoredSwaps = await _boltz.restoreLbtcLnSwaps(
            swapMasterKey: swapMasterKey,
            electrumUrl: lbtcElectrumUrl,
          );
          _logSkippedRestores(restoredSwaps.skipped);
          final obj = restoredSwaps.swaps.firstWhere(
            (s) => s.id == id,
            orElse: () => _missingFromRestore(id, restoredSwaps.skipped),
          );
          await _boltz.storage.storeLbtcLnSwap(obj);
          model = SwapModel.lnReceive(
            id: obj.id,
            type: SwapType.lightningToLiquid.name,
            recovered: true,
            boltzFees: await _recoveredBoltzFee(
              SwapType.lightningToLiquid,
              obj.outAmount.toInt(),
            ),
            status: status,
            isTestnet: _isTestnet,
            keyIndex: obj.keyIndex.toInt(),
            creationTime: creationTime,
            receiveWalletId: receiveWalletId!,
            invoice: obj.invoice,
          );
        } else {
          final restoredSwaps = await _boltz.restoreBtcLnSwaps(
            swapMasterKey: swapMasterKey,
            electrumUrl: btcElectrumUrl,
          );
          _logSkippedRestores(restoredSwaps.skipped);
          final obj = restoredSwaps.swaps.firstWhere(
            (s) => s.id == id,
            orElse: () => _missingFromRestore(id, restoredSwaps.skipped),
          );
          await _boltz.storage.storeBtcLnSwap(obj);
          model = SwapModel.lnReceive(
            id: obj.id,
            type: SwapType.lightningToBitcoin.name,
            recovered: true,
            boltzFees: await _recoveredBoltzFee(
              SwapType.lightningToBitcoin,
              obj.outAmount.toInt(),
            ),
            status: status,
            isTestnet: _isTestnet,
            keyIndex: obj.keyIndex.toInt(),
            creationTime: creationTime,
            receiveWalletId: receiveWalletId!,
            invoice: obj.invoice,
          );
        }
      case RestoredSwapKind.lightningSend:
        if (isLiquid) {
          final restoredSwaps = await _boltz.restoreLbtcLnSwaps(
            swapMasterKey: swapMasterKey,
            electrumUrl: lbtcElectrumUrl,
          );
          _logSkippedRestores(restoredSwaps.skipped);
          final obj = restoredSwaps.swaps.firstWhere(
            (s) => s.id == id,
            orElse: () => _missingFromRestore(id, restoredSwaps.skipped),
          );
          await _boltz.storage.storeLbtcLnSwap(obj);
          model = SwapModel.lnSend(
            id: obj.id,
            type: SwapType.liquidToLightning.name,
            recovered: true,
            boltzFees: await _recoveredBoltzFee(
              SwapType.liquidToLightning,
              obj.outAmount.toInt(),
            ),
            status: status,
            isTestnet: _isTestnet,
            keyIndex: obj.keyIndex.toInt(),
            creationTime: creationTime,
            sendWalletId: sendWalletId,
            invoice: obj.invoice,
            paymentAddress: obj.scriptAddress,
            paymentAmount: obj.outAmount.toInt(),
          );
        } else {
          final restoredSwaps = await _boltz.restoreBtcLnSwaps(
            swapMasterKey: swapMasterKey,
            electrumUrl: btcElectrumUrl,
          );
          _logSkippedRestores(restoredSwaps.skipped);
          final obj = restoredSwaps.swaps.firstWhere(
            (s) => s.id == id,
            orElse: () => _missingFromRestore(id, restoredSwaps.skipped),
          );
          await _boltz.storage.storeBtcLnSwap(obj);
          model = SwapModel.lnSend(
            id: obj.id,
            type: SwapType.bitcoinToLightning.name,
            recovered: true,
            boltzFees: await _recoveredBoltzFee(
              SwapType.bitcoinToLightning,
              obj.outAmount.toInt(),
            ),
            status: status,
            isTestnet: _isTestnet,
            keyIndex: obj.keyIndex.toInt(),
            creationTime: creationTime,
            sendWalletId: sendWalletId,
            invoice: obj.invoice,
            paymentAddress: obj.scriptAddress,
            paymentAmount: obj.outAmount.toInt(),
          );
        }
      case RestoredSwapKind.crossChain:
        final restoredSwaps = await _boltz.restoreChainSwaps(
          swapMasterKey: swapMasterKey,
          btcElectrumUrl: btcElectrumUrl,
          lbtcElectrumUrl: lbtcElectrumUrl,
        );
        _logSkippedRestores(restoredSwaps.skipped);
        final obj = restoredSwaps.swaps.firstWhere(
          (s) => s.id == id,
          orElse: () => _missingFromRestore(id, restoredSwaps.skipped),
        );
        await _boltz.storage.storeChainSwap(obj);
        final lockupTxid = await _boltz.chainSwapUserLockupTxid(obj);
        model = SwapModel.chain(
          id: obj.id,
          type: restored.fromAsset == 'BTC'
              ? SwapType.bitcoinToLiquid.name
              : SwapType.liquidToBitcoin.name,
          recovered: true,
          boltzFees: await _recoveredBoltzFee(
            restored.fromAsset == 'BTC'
                ? SwapType.bitcoinToLiquid
                : SwapType.liquidToBitcoin,
            obj.outAmount.toInt(),
          ),
          status: status,
          isTestnet: _isTestnet,
          keyIndex: obj.refundIndex.toInt(),
          creationTime: creationTime,
          sendWalletId: sendWalletId,
          receiveWalletId: receiveWalletId,
          sendTxid: lockupTxid,
          paymentAddress: obj.scriptAddress,
          paymentAmount: obj.outAmount.toInt(),
        );
    }

    await _boltz.storage.store(model);
    subscribeToSwaps([id]);
    await reconcileSwaps([id]);
    swapsLog.fine('SWAP_RESTORE: rescued $id as ${model.runtimeType}');
    return model.toEntity();
  }

  void _logSkippedRestores(List<boltz.SkippedRestoreSwap> skipped) {
    for (final s in skipped) {
      swapsLog.warning(
        'SWAP_RESTORE: swap ${s.id} returned by scan but not rebuildable: '
        '${s.error}',
      );
    }
  }

  Never _missingFromRestore(String id, List<boltz.SkippedRestoreSwap> skipped) {
    for (final s in skipped) {
      if (s.id == id) {
        throw 'swap $id could not be rebuilt from restore: ${s.error}';
      }
    }
    throw 'swap $id not returned by boltz restore (possibly beyond gap limit)';
  }

  /// Boltz's percentage service fee is stable, so for a recovered swap we
  /// recompute it from the live fees (rate × amount) rather than guess. Miner /
  /// network fees are NOT recomputed here — they're derived in the UI from the
  /// actual on-chain sent/received amounts. Returns null if the rate is
  /// unavailable (the swap is still rescued; the fee row is just hidden).
  Future<int?> _recoveredBoltzFee(SwapType type, int amount) async {
    try {
      final fees = await _boltz.getSwapFees(type);
      if (fees.boltzPercent == null) return null;
      return fees.boltzFeeFromPercent(amount);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Swap?> byTxId(String txId) async {
    final swapModel = await _boltz.storage.fetchByTxId(txId);
    if (swapModel == null) {
      return null; // No swap found for the given txId
    }
    return swapModel.toEntity();
  }

  Future<(SwapLimits, SwapFees)> getSwapLimitsAndFees(SwapType type) async {
    switch (type) {
      case SwapType.lightningToBitcoin:
        final (min, max) = await _boltz.getBtcReverseSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
      case SwapType.lightningToLiquid:
        final (min, max) = await _boltz.getLbtcReverseSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
      case SwapType.liquidToLightning:
        final (min, max) = await _boltz.getLbtcSubmarineSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
      case SwapType.bitcoinToLightning:
        final (min, max) = await _boltz.getBtcSubmarineSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
      case SwapType.liquidToBitcoin:
        final (min, max) = await _boltz.getLbtcToBtcChainSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
      case SwapType.bitcoinToLiquid:
        final (min, max) = await _boltz.getBtcToLbtcChainSwapLimits();
        final fees = await _boltz.getSwapFees(type);
        return (SwapLimits(min: min, max: max), fees);
    }
  }

  Future<void> updateSwapLimitsAndFees(SwapType type) async {
    await _boltz.updateFees(swapType: type);
  }

  Future<Invoice> decodeInvoice({required String invoice}) async {
    final (sats, expired, bip21, description) = await _boltz.decodeInvoice(
      invoice,
    );
    return Invoice(
      sats: sats,
      isExpired: expired,
      magicBip21: bip21,
      description: (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : null,
    );
  }

  Future<LnSendSwap?> getSendSwapByInvoice({
    required String invoice,
    required String walletId,
    required SwapType type,
  }) async {
    final allSwaps = await _boltz.storage.fetchAll(walletId: walletId);
    for (final swapModel in allSwaps) {
      final swap = swapModel.toEntity();
      if (swap.type == SwapType.lightningToBitcoin ||
          swap.type == SwapType.lightningToLiquid) {
        continue;
      }
      if (swap is LnSendSwap &&
          swap.invoice.toLowerCase() == invoice.toLowerCase() &&
          swap.status == SwapStatus.pending &&
          swap.walletId == walletId &&
          swap.type == type) {
        return swap;
      }
    }
    return null;
  }

  Future<int> getSwapRefundTxSize({
    required String swapId,
    required SwapType swapType,
    bool isCooperative = true,
    String? refundAddressForChainSwaps,
    ElectrumConnection? electrum,
  }) async {
    switch (swapType) {
      case SwapType.lightningToBitcoin:
        return 0;
      case SwapType.lightningToLiquid:
        return 0;
      case SwapType.liquidToLightning:
        return await _boltz.getLbtLnRefundTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
        );
      case SwapType.bitcoinToLightning:
        return await _boltz.getBtcLnRefundTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
        );
      case SwapType.liquidToBitcoin:
      case SwapType.bitcoinToLiquid:
        return await _boltz.getChainRefundTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
          refundAddress: refundAddressForChainSwaps!,
          electrum: electrum,
        );
    }
  }

  Future<String?> getSendSwapPreimage({required String swapId}) async {
    final swap = await getSwap(swapId: swapId);
    if (swap is! LnSendSwap) {
      throw Exception('Swap is not a send swap');
    }
    switch (swap.type) {
      case SwapType.bitcoinToLightning:
        return await _boltz.getBtcLnSwapPreimage(swapId: swapId);
      case SwapType.liquidToLightning:
        return await _boltz.getLbtcLnSwapPreimage(swapId: swapId);
      default:
        throw Exception('Swap type does not support preimage');
    }
  }

  Future<void> migrateOldSwap({
    required String primaryWalletId,
    required String swapId,
    required SwapType swapType,
    required String? lockupTxid,
    required String? counterWalletId,
    required bool? isCounterWalletExternal,
    required String? claimAddress,
  }) async {
    switch (swapType) {
      case SwapType.lightningToBitcoin:
        final swapObject = await _boltz.storage.fetchBtcLnSwap(swapId);
        await _boltz.fromBtcLnSwapObjectMigration(
          swapObject,
          primaryWalletId,
          null,
          lockupTxid,
          claimAddress,
        );
      case SwapType.bitcoinToLightning:
        final swapObject = await _boltz.storage.fetchBtcLnSwap(swapId);
        await _boltz.fromBtcLnSwapObjectMigration(
          swapObject,
          null,
          primaryWalletId,
          lockupTxid,
          null,
        );
      case SwapType.lightningToLiquid:
        final swapObject = await _boltz.storage.fetchLbtcLnSwap(swapId);
        await _boltz.fromLbtcLnSwapObjectMigration(
          swapObject,
          primaryWalletId,
          null,
          lockupTxid,
          claimAddress,
        );
      case SwapType.liquidToLightning:
        final swapObject = await _boltz.storage.fetchLbtcLnSwap(swapId);
        await _boltz.fromLbtcLnSwapObjectMigration(
          swapObject,
          null,
          primaryWalletId,
          lockupTxid,
          null,
        );
      case SwapType.liquidToBitcoin:
        final swapObject = await _boltz.storage.fetchChainSwap(swapId);
        if (counterWalletId == null || isCounterWalletExternal == null) {
          throw Exception(
            'Counter wallet ID and isCounterWalletExternal must be provided for chain swaps',
          );
        }
        await _boltz.fromChainSwapObjectMigration(
          swapObject,
          primaryWalletId,
          counterWalletId,
          isCounterWalletExternal,
          lockupTxid,
        );

      case SwapType.bitcoinToLiquid:
        if (counterWalletId == null || isCounterWalletExternal == null) {
          throw Exception(
            'Counter wallet ID and isCounterWalletExternal must be provided for chain swaps',
          );
        }
        final swapObject = await _boltz.storage.fetchChainSwap(swapId);
        await _boltz.fromChainSwapObjectMigration(
          swapObject,
          primaryWalletId,
          counterWalletId,
          isCounterWalletExternal,
          lockupTxid,
        );
    }
  }

  /// Lists the spends of the swap's lockup tx outputs, one per spent vout.
  /// An entry proves only that an output was spent — never that we were
  /// paid; callers must verify a spender against their own wallet before
  /// settling the swap on it.
  Future<List<SwapTxOutspend>> checkLockupOutspends({
    required String swapId,
    required SwapType swapType,
    required Network network,
    outspend.SwapDirection? swapDirection,
    bool isClaim = true,
  }) async {
    final models = await _boltz.checkLockupOutspends(
      swapId: swapId,
      swapType: swapType,
      network: network,
      swapDirection: swapDirection,
      isClaim: isClaim,
    );
    return models.map((model) => model.toEntity()).toList();
  }

  /// Fingerprint of the default bitcoin wallet for this environment; null
  /// when none exists. Used by the seed viewer's swap-key usecases.
  Future<String?> defaultBitcoinFingerprint() async {
    final wallets = await _wallets(isTestnet: _isTestnet);
    for (final w in wallets) {
      if (w.isDefault && !w.isLiquid && w.fingerprint.isNotEmpty) {
        return w.fingerprint;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // SwapRepository interface
  // ---------------------------------------------------------------------

  @override
  bool get isTestnet => _isTestnet;

  @override
  Stream<Swap> get updates => swapUpdatesStream;

  @override
  Future<Swap> get(String swapId) => getSwap(swapId: swapId);

  @override
  Stream<Swap> watch(String swapId) => watchSwap(swapId: swapId);

  @override
  Future<List<Swap>> all({String? walletId}) => getAllSwaps(walletId: walletId);

  @override
  Future<List<Swap>> ongoing({String? walletId}) =>
      getOngoingSwaps(walletId: walletId);

  @override
  void listen(List<String> swapIds) => subscribeToSwaps(swapIds);

  @override
  Future<void> reconcile(List<String> swapIds) => reconcileSwaps(swapIds);

  Future<String> _electrumUrl({required bool isLiquid}) => _electrum.run(
    isLiquid: isLiquid,
    isTestnet: _isTestnet,
    operation: (connection) async => connection.url,
  );

  @override
  Future<LnReceiveSwap> createLightningReceive({
    required String walletId,
    required int amountSat,
    required bool toLiquid,
    String? description,
  }) async {
    await _ensureMasterKey();
    final electrumUrl = await _electrumUrl(isLiquid: toLiquid);
    final claimAddress = await _newAddressFor(walletId);
    return toLiquid
        ? createLightningToLiquidSwap(
            walletId: walletId,
            amountSat: amountSat,
            electrumUrl: electrumUrl,
            claimAddress: claimAddress,
            description: description,
          )
        : createLightningToBitcoinSwap(
            walletId: walletId,
            amountSat: amountSat,
            electrumUrl: electrumUrl,
            claimAddress: claimAddress,
            description: description,
          );
  }

  @override
  Future<LnSendSwap> createLightningSend({
    required String walletId,
    required String invoice,
    required bool fromLiquid,
  }) async {
    await _ensureMasterKey();
    final electrumUrl = await _electrumUrl(isLiquid: fromLiquid);
    return fromLiquid
        ? createLiquidToLightningSwap(
            walletId: walletId,
            invoice: invoice,
            electrumUrl: electrumUrl,
          )
        : createBitcoinToLightningSwap(
            walletId: walletId,
            invoice: invoice,
            electrumUrl: electrumUrl,
          );
  }

  @override
  Future<ChainSwap> createChain({
    required String sendWalletId,
    required int amountSat,
    required bool fromLiquid,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    await _ensureMasterKey();
    final btcElectrumUrl = await _electrumUrl(isLiquid: false);
    final lbtcElectrumUrl = await _electrumUrl(isLiquid: true);
    return fromLiquid
        ? createLiquidToBitcoinSwap(
            sendWalletId: sendWalletId,
            amountSat: amountSat,
            btcElectrumUrl: btcElectrumUrl,
            lbtcElectrumUrl: lbtcElectrumUrl,
            receiveWalletId: receiveWalletId,
            externalRecipientAddress: externalRecipientAddress,
          )
        : createBitcoinToLiquidSwap(
            sendWalletId: sendWalletId,
            amountSat: amountSat,
            btcElectrumUrl: btcElectrumUrl,
            lbtcElectrumUrl: lbtcElectrumUrl,
            receiveWalletId: receiveWalletId,
            externalRecipientAddress: externalRecipientAddress,
          );
  }

  // RESOLVE OPERATIONS — the watcher's verbs. Each resolves its own
  // address, estimates fees (floored at relay minimum, capped at half the
  // swap amount), tries the cooperative path first and falls back to the
  // script path, walks the app's electrum servers, and records the outcome.

  @override
  Future<String> claim(Swap swap) async {
    final existing = switch (swap) {
      LnReceiveSwap() => swap.receiveTxid,
      ChainSwap() => swap.receiveTxid,
      LnSendSwap() => throw SwapsException(
        'submarine swap ${swap.id} is refunded or coop-signed, never claimed',
      ),
    };
    if (existing != null) return existing;
    if (swap is LnReceiveSwap && swap.wasDirectPayment) {
      return swap.receiveTxid ?? '';
    }

    final claimAddress = await _resolveClaimAddress(swap);
    final claimOnLiquid = switch (swap) {
      LnReceiveSwap() => swap.type == SwapType.lightningToLiquid,
      ChainSwap() => swap.type == SwapType.bitcoinToLiquid,
      LnSendSwap() => false,
    };

    try {
      return await _electrum.run(
        isLiquid: claimOnLiquid,
        isTestnet: _isTestnet,
        isTransient: _isServerFailure,
        operation: (connection) async {
          // Pin the claim fee to the stored creation-time claimFee: the
          // receive/transfer screens promise amount-minus-quoted-fees, so a
          // live fee changes what the user actually receives. Rescued swaps
          // carry no trustworthy stored fee and use live estimation.
          final storedClaimFee = swap.fees?.claimFee;
          int absoluteFees;
          if (storedClaimFee != null && storedClaimFee > 0) {
            absoluteFees = storedClaimFee;
          } else {
            // Cooperative sizing round-trips Boltz and can fail (notably for
            // rescued swaps); the script-path size is computed locally, so
            // try that next — same fallback the original watcher had.
            int txSize;
            try {
              txSize = await getSwapClaimTxSize(
                swapId: swap.id,
                swapType: swap.type,
                claimAddressForChainSwaps: swap is ChainSwap
                    ? claimAddress
                    : null,
              );
            } catch (_) {
              txSize = await getSwapClaimTxSize(
                swapId: swap.id,
                swapType: swap.type,
                isCooperative: false,
                claimAddressForChainSwaps: swap is ChainSwap
                    ? claimAddress
                    : null,
              );
            }
            absoluteFees = await _resolveFees(
              txSize: txSize,
              isLiquid: claimOnLiquid,
              amountSat: _amountSatOrNull(swap),
            );
          }
          unsubscribeFromSwaps([swap.id]);
          String txid;
          try {
            txid = await _broadcastClaim(
              swap,
              claimAddress: claimAddress,
              absoluteFees: absoluteFees,
              cooperate: true,
            );
          } catch (e) {
            swapsLog.severe(
              'SWAPS: coop claim failed for ${swap.id} '
              '(${_errorMessage(e)}); trying script path',
              error: e,
            );
            txid = await _broadcastClaim(
              swap,
              claimAddress: claimAddress,
              absoluteFees: absoluteFees,
              cooperate: false,
            );
          }
          await updateSwapFields(
            swap.id,
            status: SwapStatus.completed,
            receiveTxid: txid,
            receiveAddress: claimAddress,
            claimFee: absoluteFees,
            completionTime: DateTime.now(),
          );
          swapsLog.fine(
            'SWAPS: claim succeeded for ${swap.id} txid=$txid '
            'fees=$absoluteFees server=${connection.url}',
          );
          await swapsLog.flush();
          return txid;
        },
      );
    } catch (e) {
      final recovered = await _recoverFromVerifiedOutspend(swap, isClaim: true);
      await swapsLog.flush();
      if (recovered != null) return recovered;
      listen([swap.id]);
      throw SwapsException('claim failed for ${swap.id}: ${_errorMessage(e)}');
    }
  }

  @override
  Future<String> refund(Swap swap) async {
    final existing = switch (swap) {
      ChainSwap() => swap.refundTxid,
      LnSendSwap() => swap.refundTxid,
      LnReceiveSwap() => throw SwapsException(
        'reverse swap ${swap.id} is claimed, never refunded',
      ),
    };
    if (existing != null) return existing;

    final refundOnLiquid = switch (swap.type) {
      SwapType.liquidToBitcoin || SwapType.liquidToLightning => true,
      _ => false,
    };
    final sendWalletId = switch (swap) {
      ChainSwap() => swap.sendWalletId,
      LnSendSwap() => swap.sendWalletId,
      LnReceiveSwap() => null,
    };
    if (sendWalletId == null) {
      throw SwapsException('swap ${swap.id} has no wallet to refund into');
    }
    final refundAddress =
        switch (swap) {
          ChainSwap() => swap.refundAddress,
          LnSendSwap() => swap.refundAddress,
          LnReceiveSwap() => null,
        } ??
        await _persistRefundAddress(swap.id, sendWalletId);

    try {
      final (txid, _) = await _electrum.run(
        isLiquid: refundOnLiquid,
        isTestnet: _isTestnet,
        isTransient: _isServerFailure,
        operation: (connection) => _attemptRefund(
          swap,
          refundAddress: refundAddress,
          isLiquid: refundOnLiquid,
          connection: connection,
        ),
      );
      return txid;
    } catch (e) {
      swapsLog.severe(
        'SWAPS: refund failed for ${swap.id}: ${_errorMessage(e)}',
        error: e,
      );
      // A non-final rejection means the timelock has not passed — nothing of
      // ours can be on-chain, so the outspend recovery must not get the
      // chance to match an unrelated spend.
      if (_isNonFinalError(e)) {
        await swapsLog.flush();
        throw SwapsException(
          'refund for ${swap.id} is not yet final (timelock); retry later',
        );
      }
      final recovered = await _recoverFromVerifiedOutspend(
        swap,
        isClaim: false,
      );
      await swapsLog.flush();
      if (recovered != null) return recovered;
      throw SwapsException('refund failed for ${swap.id}: ${_errorMessage(e)}');
    }
  }

  @override
  Future<void> coopSign(Swap swap) async {
    if (swap is! LnSendSwap) return;
    try {
      if (swap.preimage == null) {
        final preimage = await getSendSwapPreimage(swapId: swap.id);
        if (preimage != null) {
          await updateSwapFields(swap.id, preimage: preimage);
        }
      }
      if (swap.type == SwapType.bitcoinToLightning) {
        await coopSignBitcoinToLightningSwap(swapId: swap.id);
      } else {
        await coopSignLiquidToLightningSwap(swapId: swap.id);
      }
      unsubscribeFromSwaps([swap.id]);
      swapsLog.fine('SWAPS: coop close succeeded for ${swap.id}');
    } catch (e) {
      // Non-fatal: the payment is already made; Boltz completes via the
      // script path and the swap settles on transaction.claimed.
      swapsLog.warning(
        'SWAPS: coop close failed for ${swap.id} (${_errorMessage(e)}); '
        'swap completes via transaction.claimed',
      );
      rethrow;
    }
  }

  Future<(String, int)> _attemptRefund(
    Swap swap, {
    required String refundAddress,
    required bool isLiquid,
    required ElectrumConnection connection,
  }) async {
    Future<String> broadcast({required bool cooperate, required int fees}) {
      switch (swap.type) {
        case SwapType.liquidToBitcoin:
          return refundLiquidToBitcoinSwap(
            swapId: swap.id,
            liquidRefundAddress: refundAddress,
            absoluteFees: fees,
            cooperate: cooperate,
            electrum: connection,
          );
        case SwapType.bitcoinToLiquid:
          return refundBitcoinToLiquidSwap(
            swapId: swap.id,
            bitcoinRefundAddress: refundAddress,
            absoluteFees: fees,
            cooperate: cooperate,
            electrum: connection,
          );
        case SwapType.liquidToLightning:
          return refundLiquidToLightningSwap(
            swapId: swap.id,
            liquidAddress: refundAddress,
            absoluteFees: fees,
            cooperate: cooperate,
          );
        case SwapType.bitcoinToLightning:
          return refundBitcoinToLightningSwap(
            swapId: swap.id,
            bitcoinAddress: refundAddress,
            absoluteFees: fees,
            cooperate: cooperate,
          );
        case SwapType.lightningToBitcoin:
        case SwapType.lightningToLiquid:
          throw SwapsException('reverse swap has no refund');
      }
    }

    Future<int> feesFor({required bool cooperative}) async => _resolveFees(
      txSize: await getSwapRefundTxSize(
        swapId: swap.id,
        swapType: swap.type,
        isCooperative: cooperative,
        refundAddressForChainSwaps: swap is ChainSwap ? refundAddress : null,
        electrum: swap is ChainSwap ? connection : null,
      ),
      isLiquid: isLiquid,
      amountSat: _amountSatOrNull(swap),
    );

    String txid;
    int fees;
    try {
      fees = await feesFor(cooperative: true);
      swapsLog.fine(
        'SWAPS: ${swap.id} cooperative refund fees=$fees '
        'server=${connection.url}',
      );
      txid = await broadcast(cooperate: true, fees: fees);
    } catch (e) {
      swapsLog.severe(
        'SWAPS: coop refund failed for ${swap.id} '
        '(${_errorMessage(e)}); trying script path (Boltz-free)',
        error: e,
      );
      fees = await feesFor(cooperative: false);
      swapsLog.fine(
        'SWAPS: ${swap.id} script-path refund fees=$fees '
        'server=${connection.url}',
      );
      txid = await broadcast(cooperate: false, fees: fees);
    }
    await updateSwapFields(
      swap.id,
      status: SwapStatus.refunded,
      refundTxid: txid,
      refundAddress: refundAddress,
      refundFee: fees,
      completionTime: DateTime.now(),
    );
    swapsLog.fine('SWAPS: refund succeeded for ${swap.id} txid=$txid');
    await swapsLog.flush();
    return (txid, fees);
  }

  Future<String> _resolveClaimAddress(Swap swap) async {
    switch (swap) {
      case LnReceiveSwap():
        final existing = swap.receiveAddress;
        if (existing != null) return existing;
        final address = await _newAddressFor(swap.receiveWalletId);
        await updateSwapFields(swap.id, receiveAddress: address);
        return address;
      case ChainSwap():
        final existing = swap.receiveAddress;
        if (existing != null) {
          final uri = Uri.tryParse(existing);
          if (uri != null && uri.scheme.isNotEmpty && uri.path.isNotEmpty) {
            // bip21-style stored destination (bitcoin:/liquidnetwork:...).
            return uri.path;
          }
          return existing;
        }
        final receiveWalletId = swap.receiveWalletId;
        if (receiveWalletId == null) {
          throw SwapsException(
            'chain swap ${swap.id} has neither a receive wallet nor a '
            'receive address',
          );
        }
        final address = await _newAddressFor(receiveWalletId);
        await updateSwapFields(swap.id, receiveAddress: address);
        return address;
      case LnSendSwap():
        throw SwapsException('submarine swaps have no claim address');
    }
  }

  Future<String> _persistRefundAddress(String swapId, String walletId) async {
    final address = await _newAddressFor(walletId);
    await updateSwapFields(swapId, refundAddress: address);
    return address;
  }

  /// Live fee, floored at the relay minimum (a lower fee cannot broadcast)
  /// and capped at half the swap amount (an automatic action must never burn
  /// the swap on fees). Fee-API outage falls back to the floor itself.
  Future<int> _resolveFees({
    required int txSize,
    required bool isLiquid,
    int? amountSat,
  }) async {
    final floor = isLiquid ? (txSize * 0.11).ceil() + 1 : txSize;
    int fees;
    try {
      final live = await _fastestFee(
        txSize: txSize,
        isLiquid: isLiquid,
        isTestnet: _isTestnet,
      );
      fees = live > floor ? live : floor;
    } catch (e) {
      swapsLog.warning(
        'SWAPS: fee estimation unavailable ($e) — using relay floor $floor '
        'for txSize=$txSize',
      );
      fees = floor;
    }
    if (amountSat != null && amountSat > 0) {
      final cap = amountSat ~/ 2;
      if (fees > cap && cap >= floor) fees = cap;
    }
    return fees;
  }

  Future<String> _broadcastClaim(
    Swap swap, {
    required String claimAddress,
    required int absoluteFees,
    required bool cooperate,
  }) {
    switch (swap.type) {
      case SwapType.lightningToBitcoin:
        return claimLightningToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: absoluteFees,
          bitcoinAddress: claimAddress,
          cooperate: cooperate,
        );
      case SwapType.lightningToLiquid:
        return claimLightningToLiquidSwap(
          swapId: swap.id,
          absoluteFees: absoluteFees,
          liquidAddress: claimAddress,
          cooperate: cooperate,
        );
      case SwapType.bitcoinToLiquid:
        return claimBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: absoluteFees,
          liquidClaimAddress: claimAddress,
          cooperate: cooperate,
        );
      case SwapType.liquidToBitcoin:
        return claimLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: absoluteFees,
          bitcoinClaimAddress: claimAddress,
          cooperate: cooperate,
        );
      case SwapType.bitcoinToLightning:
      case SwapType.liquidToLightning:
        throw SwapsException('submarine swaps have no claim transaction');
    }
  }

  int? _amountSatOrNull(Swap swap) {
    try {
      return swap.amountSat;
    } catch (_) {
      return null;
    }
  }

  /// After a failed broadcast: is the relevant lockup already spent by a tx
  /// that actually PAID us? Only an incoming transaction of the wallet the
  /// funds must land in settles the swap — a spend of the lockup's change
  /// output by our own wallet, or Boltz spending its own side, must never.
  /// Fail closed: no verified candidate leaves the swap actionable.
  Future<String?> _recoverFromVerifiedOutspend(
    Swap swap, {
    required bool isClaim,
  }) async {
    try {
      final walletId = switch (swap) {
        ChainSwap() => isClaim ? swap.receiveWalletId : swap.sendWalletId,
        LnReceiveSwap() => swap.receiveWalletId,
        LnSendSwap() => swap.sendWalletId,
      };
      if (walletId == null) return null;

      final network = switch (swap) {
        ChainSwap() => Network.fromEnvironment(
          isTestnet: _isTestnet,
          isLiquid: isClaim
              ? swap.type == SwapType.bitcoinToLiquid
              : swap.type == SwapType.liquidToBitcoin,
        ),
        LnReceiveSwap() => Network.fromEnvironment(
          isTestnet: _isTestnet,
          isLiquid: swap.type == SwapType.lightningToLiquid,
        ),
        LnSendSwap() => Network.fromEnvironment(
          isTestnet: _isTestnet,
          isLiquid: swap.type == SwapType.liquidToLightning,
        ),
      };
      final direction = swap is ChainSwap
          ? (swap.type == SwapType.liquidToBitcoin
                ? outspend.SwapDirection.liquidToBitcoin
                : outspend.SwapDirection.bitcoinToLiquid)
          : null;

      final outspends = await checkLockupOutspends(
        swapId: swap.id,
        swapType: swap.type,
        network: network,
        swapDirection: direction,
        isClaim: isClaim,
      );
      if (outspends.isEmpty) {
        swapsLog.fine(
          'SWAPS: ${swap.id} lockup outputs unspent — still actionable',
        );
        return null;
      }

      for (final candidate in outspends) {
        final txid = candidate.txid;
        if (txid == null) continue;
        final tx = await _walletTx(txid, walletId: walletId);
        if (tx == null) continue;
        if (!tx.isIncoming) {
          swapsLog.fine(
            'SWAPS: ${swap.id} spender $txid is in our wallet but not '
            'incoming (change/self spend) — ignoring',
          );
          continue;
        }
        swapsLog.fine(
          'SWAPS: ${swap.id} ${isClaim ? 'claim' : 'refund'} already '
          'on-chain as $txid (verified incoming) — settling',
        );
        await updateSwapFields(
          swap.id,
          status: isClaim ? SwapStatus.completed : SwapStatus.refunded,
          receiveTxid: isClaim ? txid : null,
          refundTxid: isClaim ? null : txid,
          completionTime: candidate.timestamp ?? DateTime.now(),
        );
        return txid;
      }
      swapsLog.warning(
        'SWAPS: ${swap.id} lockup spent by '
        '${outspends.map((o) => o.txid).whereType<String>().join(',')} but '
        'none is an incoming tx of our wallet — NOT settling',
      );
      return null;
    } catch (e) {
      swapsLog.severe('SWAPS: outspend check failed for ${swap.id}', error: e);
      return null;
    }
  }

  bool _isNonFinalError(Object error) {
    final message = _errorMessage(error).toLowerCase();
    return message.contains('non-final') ||
        message.contains('non_final') ||
        message.contains('nonfinal') ||
        message.contains('non-bip68-final') ||
        message.contains('locktime');
  }

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

  String _errorMessage(Object error) =>
      error is boltz.BoltzError ? error.message : error.toString();

  /// Binds (or first derives) the swap master key so restore/rescue can run.
  /// Every 6.13 build shipped with the key never bound — restore threw
  /// unconditionally; the engine now self-ensures instead of trusting a
  /// startup hook that can be refactored away.
  Future<void> _ensureMasterKey() async {
    final source = await _masterSeedSource(isTestnet: _isTestnet);
    if (source == null) {
      throw SwapsException(
        'no default bitcoin wallet seed available to derive the swap '
        'master key (watch-only or hardware-only wallet)',
      );
    }
    if (await swapMasterKeyReady(walletFingerprint: source.fingerprint)) {
      return;
    }
    await deriveSwapMasterKey(
      mnemonic: source.mnemonic,
      walletFingerprint: source.fingerprint,
    );
    swapsLog.fine(
      'SWAPS: swap master key derived for wallet ${source.fingerprint}',
    );
  }

  @override
  Future<List<RestoredSwap>> restore() async {
    await _ensureMasterKey();
    return restoreSwaps(isTestnet: _isTestnet);
  }

  @override
  Future<Swap> rescue(RestoredSwap restored, {required String walletId}) async {
    await _ensureMasterKey();
    final btcElectrumUrl = await _electrumUrl(isLiquid: false);
    final lbtcElectrumUrl = await _electrumUrl(isLiquid: true);

    final wallets = await _wallets(isTestnet: _isTestnet);
    String? defaultIdForLiquid(bool wantLiquid) {
      for (final w in wallets) {
        if (w.isDefault && w.isLiquid == wantLiquid) return w.id;
      }
      return null;
    }

    String sendWalletId;
    String? receiveWalletId;
    switch (restored.kind) {
      case RestoredSwapKind.lightningReceive:
        receiveWalletId = walletId;
        sendWalletId = walletId;
      case RestoredSwapKind.lightningSend:
        sendWalletId = walletId;
        receiveWalletId = null;
      case RestoredSwapKind.crossChain:
        if (restored.isRefundAction) {
          sendWalletId = walletId;
          receiveWalletId = null;
        } else {
          receiveWalletId = walletId;
          sendWalletId =
              defaultIdForLiquid(restored.fromAsset == 'L-BTC') ??
              (throw SwapsException(
                'no default ${restored.fromAsset} wallet for the refund side',
              ));
        }
    }
    swapsLog.fine(
      'SWAPS: rescuing ${restored.id} (${restored.kind.name}) '
      'send=$sendWalletId receive=$receiveWalletId',
    );
    return rescueSwap(
      restored: restored,
      sendWalletId: sendWalletId,
      receiveWalletId: receiveWalletId,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
    );
  }

  /// Re-verifies recorded chain-swap completions against the receiving
  /// wallet and reopens the ones that never paid us as refundable.
  /// Cache-first: the wallet is only force-synced when the recorded claim is
  /// MISSING from the cached view, so the common all-good launch does no
  /// network work per swap.
  @override
  Future<void> verifyCompletions() async {
    try {
      final swaps = await getAllSwaps();
      for (final swap in swaps) {
        if (swap is! ChainSwap) continue;
        if (swap.status != SwapStatus.completed) continue;
        if (swap.refundTxid != null) continue;
        if (swap.sendTxid == null) continue;
        final receiveTxid = swap.receiveTxid;
        if (receiveTxid == null) {
          swapsLog.warning(
            'SWAPS: ${swap.id} completed with funds locked and no txid '
            'recorded — reopening as refundable',
          );
          await updateSwapFields(swap.id, status: SwapStatus.refundable);
          continue;
        }
        final walletId = swap.receiveWalletId;
        if (walletId == null) continue;
        try {
          var txs = await _walletTxs(walletId);
          if (txs.any((tx) => tx.txId == receiveTxid)) continue;
          // Missing from cache: force one fresh sync before judging. A sync
          // failure throws into the per-swap catch — never retract on a
          // cache we could not freshen.
          txs = await _walletTxs(walletId, sync: true);
          if (txs.isEmpty) continue;
          if (txs.any((tx) => tx.txId == receiveTxid)) continue;
          swapsLog.warning(
            'SWAPS: ${swap.id} completed but recorded claim $receiveTxid is '
            'not in wallet $walletId — retracting and reopening as '
            'refundable',
          );
          await updateSwapFields(
            swap.id,
            status: SwapStatus.refundable,
            clearReceiveTxid: true,
          );
        } catch (e) {
          swapsLog.warning('SWAPS: verify failed for ${swap.id}: $e');
        }
      }
      await swapsLog.flush();
    } catch (e) {
      swapsLog.warning('SWAPS: verifyCompletions failed: $e');
    }
  }
}
