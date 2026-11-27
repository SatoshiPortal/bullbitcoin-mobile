import 'package:flutter/widgets.dart' show TextStyle, Widget;
import 'package:swaps/src/widgets/swap_mnemonic_view.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import 'dart:async';

import 'package:swaps/src/util.dart';
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/domain/boltz_swaps.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_resolver.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result, NetworkEnv;
import 'package:swaps/src/data/models/swap_model.dart';
import 'package:swaps/src/domain/entities/derived_swap_master_key.dart';
import 'package:swaps/src/domain/entities/restored_swap.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_master_key_info.dart';
import 'package:swaps/src/domain/entities/swap_server.dart';
import 'package:swaps/src/domain/entities/swap_tx_outspend.dart'
    hide SwapDirection;
import 'package:swaps/src/domain/entities/swap_tx_outspend.dart' as outspend;
import 'package:swaps/src/log.dart';
import 'package:rust_bindings/boltz.dart' as boltz;

/// Fresh receive address on [walletId], for claim/refund destinations.
typedef NewAddressFor = Future<Result<String, SwapsFailure>> Function(
  String walletId,
);

/// Look up one wallet transaction (null when absent) from the wallet's
/// current view — the caller is responsible for any freshening it needs
/// (app-level syncs converge; the outspend recovery reads whatever the
/// wallet knows at that moment and fails closed on absence).
typedef WalletTxLookup = Future<SwapWalletTx?> Function(
  String txid, {
  required String walletId,
});

/// All of a wallet's transactions. [sync] freshens the wallet first.
/// A null result means the read or requested refresh was unavailable.
typedef WalletTxsLookup = Future<List<SwapWalletTx>?> Function(
  String walletId, {
  bool sync,
});

/// Fastest-confirmation absolute fee for [txSize] vbytes; throws when the
/// estimate is unavailable (the engine falls back to the relay floor).
typedef FastestFee = Future<int> Function({
  required int txSize,
  required bool isLiquid,
  required NetworkEnv environment,
});

typedef WalletsList = Future<List<SwapWalletInfo>> Function({
  required NetworkEnv environment,
});

/// The swap master key derived from the default bitcoin wallet by the app's
/// secrets layer; null when unavailable (watch-only / hardware-only /
/// pre-onboarding). Only invoked when no key is stored yet.
typedef SwapMasterKeySource = Future<DerivedSwapMasterKey?> Function({
  required NetworkEnv environment,
});

class BoltzSwapRepository implements SwapResolver, BoltzSwaps {
  final BoltzDatasource _boltz;
  final NetworkEnv _environment;
  final ElectrumRunner _electrum;
  final NewAddressFor _newAddressFor;
  final WalletTxLookup _walletTx;
  final WalletTxsLookup _walletTxs;
  final FastestFee _fastestFee;
  final WalletsList _wallets;
  final SwapMasterKeySource _swapMasterKeySource;
  final LockupChain _lockupChain;

  /// Serializes swap creation so two concurrent creations can never compute
  /// the same key index from a stale table scan.
  Future<void> _creationLock = Future.value();
  bool _effectsSuspended = false;

  @override
  void suspendEffects() => _effectsSuspended = true;

  @override
  void resumeEffects() => _effectsSuspended = false;

  void _requireEffectAdmission() {
    if (_effectsSuspended) throw const SwapsBusyFailure();
  }

  BoltzSwapRepository({
    required this._boltz,
    required this._environment,
    required this._electrum,
    required this._newAddressFor,
    required this._walletTx,
    required this._walletTxs,
    required this._fastestFee,
    required this._wallets,
    required this._swapMasterKeySource,
    required this._lockupChain,
  }) {
    if (_boltz.environment != _environment ||
        (_environment == NetworkEnv.regtest) != _boltz.storage.isRegtestStore) {
      throw ArgumentError('Swap engine and storage network differ');
    }
    _boltz.effectAdmission = _requireEffectAdmission;
  }

  /// The Boltz provider on the backend at [url], over the shared [storage].
  factory BoltzSwapRepository.connect({
    required String url,
    SwapServerCredentials? credentials,
    String? webSocketUrl,
    String? bitcoinExplorerUrl,
    String? liquidExplorerUrl,
    required SwapStorage storage,
    required NetworkEnv environment,
    required ElectrumRunner electrum,
    required LockupChain lockupChain,
    required NewAddressFor newAddressFor,
    required WalletTxLookup walletTx,
    required WalletTxsLookup walletTxs,
    required FastestFee fastestFee,
    required WalletsList wallets,
    required SwapMasterKeySource swapMasterKeySource,
  }) => BoltzSwapRepository(
    boltz: BoltzDatasource(
      url: url,
      credentials: credentials,
      environment: environment,
      webSocketUrl: webSocketUrl,
      bitcoinExplorerUrl: bitcoinExplorerUrl,
      liquidExplorerUrl: liquidExplorerUrl,
      boltzStore: storage,
    ),
    environment: environment,
    electrum: electrum,
    lockupChain: lockupChain,
    newAddressFor: newAddressFor,
    walletTx: walletTx,
    walletTxs: walletTxs,
    fastestFee: fastestFee,
    wallets: wallets,
    swapMasterKeySource: swapMasterKeySource,
  );

  /// Closes the backend connection; the provider is unusable afterwards.
  void dispose() => _boltz.dispose();

  /// Joins provider event writes, not native creations already admitted here.
  Future<void> close() => _boltz.close();

  Future<T> _withCreationLock<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _creationLock;
    _creationLock = completer.future;
    return previous
        .catchError((_) {})
        .then((_) => action())
        .whenComplete(completer.complete);
  }

  Stream<Swap> get swapUpdatesStream => _boltz.swapUpdatesStream.map(
    (swapModel) => swapModel.toEntity(
      environment: Environment.fromName(_environment.name),
    ),
  );

  /// RECEIVE LN TO BTC

  Future<LnReceiveSwap> _boltzCreateLightningToBitcoinSwap({
    required String walletId,
    required int amountSat,
    required ElectrumConnection electrum,
    required String claimAddress,
    String? description,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final btcLnSwap = await _boltz.createBtcReverseSwap(
        walletId: walletId,
        index: index,
        outAmount: amountSat,
        environment: _environment,
        electrum: electrum,
        magicRouteHintAddress: claimAddress,
        description: description,
      );
      return btcLnSwap.toEntity(
        environment: Environment.fromName(_environment.name),
      ) as LnReceiveSwap;
    });
  }

  Future<String> claimLightningToBitcoinSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
    bool cooperate = true,
    ElectrumConnection? electrum,
  }) async {
    _requireEffectAdmission();
    final txid = await _boltz.claimBtcReverseSwap(
      swapId: swapId,
      claimAddress: bitcoinAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
      electrum: electrum,
    );

    return await _boltz.broadcastBtcLnSwap(
      swapId: swapId,
      signedTxHex: txid,
      broadcastViaBoltz: false,
      electrum: electrum,
    );
  }

  /// RECEIVE LN TO LBTC

  Future<LnReceiveSwap> _boltzCreateLightningToLiquidSwap({
    required String walletId,
    required int amountSat,
    required ElectrumConnection electrum,
    required String claimAddress,
    String? description,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final lbtcLnSwap = await _boltz.createLBtcReverseSwap(
        walletId: walletId,
        index: index,
        outAmount: amountSat,
        environment: _environment,
        electrum: electrum,
        magicRouteHintAddress: claimAddress,
        description: description,
      );

      return lbtcLnSwap.toEntity(
        environment: Environment.fromName(_environment.name),
      ) as LnReceiveSwap;
    });
  }

  Future<String> claimLightningToLiquidSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
    bool cooperate = true,
    ElectrumConnection? electrum,
  }) async {
    _requireEffectAdmission();
    final signedTxHex = await _boltz.claimLBtcReverseSwap(
      swapId: swapId,
      claimAddress: liquidAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
      electrum: electrum,
    );

    return await _boltz.broadcastLbtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
      electrum: electrum,
    );
  }

  /// SEND BTC TO LN

  Future<LnSendSwap> _boltzCreateBitcoinToLightningSwap({
    required String walletId,
    required String invoice,
    required ElectrumConnection electrum,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final btcLnSwap = await _boltz.createBtcSubmarineSwap(
        walletId: walletId,
        index: index,
        invoice: invoice,
        environment: _environment,
        electrum: electrum,
      );

      return btcLnSwap.toEntity(
        environment: Environment.fromName(_environment.name),
      ) as LnSendSwap;
    });
  }

  Future<void> coopSignBitcoinToLightningSwap({required String swapId}) async {
    _requireEffectAdmission();
    await _boltz.coopSignBtcSubmarineSwap(swapId: swapId);
    await _updateCompletedSendSwap(swapId: swapId);
    return;
  }

  Future<String> refundBitcoinToLightningSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
    bool cooperate = true,
    ElectrumConnection? electrum,
  }) async {
    _requireEffectAdmission();
    final signedTxHex = await _boltz.refundBtcSubmarineSwap(
      swapId: swapId,
      refundAddress: bitcoinAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
      electrum: electrum,
    );

    return await _boltz.broadcastBtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
      electrum: electrum,
    );
  }

  /// SEND LBTC TO LN

  Future<LnSendSwap> _boltzCreateLiquidToLightningSwap({
    required String walletId,
    required String invoice,
    required ElectrumConnection electrum,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(1);
      final lbtcLnSwap = await _boltz.createLbtcSubmarineSwap(
        walletId: walletId,
        index: index,
        invoice: invoice,
        environment: _environment,
        electrum: electrum,
      );

      return lbtcLnSwap.toEntity(
        environment: Environment.fromName(_environment.name),
      ) as LnSendSwap;
    });
  }

  Future<void> coopSignLiquidToLightningSwap({required String swapId}) async {
    _requireEffectAdmission();
    await _boltz.coopSignLbtcSubmarineSwap(swapId: swapId);
    await _updateCompletedSendSwap(swapId: swapId);
    return;
  }

  Future<String> refundLiquidToLightningSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
    bool cooperate = true,
    ElectrumConnection? electrum,
  }) async {
    _requireEffectAdmission();
    final signedTxHex = await _boltz.refundLbtcSubmarineSwap(
      swapId: swapId,
      refundAddress: liquidAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
      electrum: electrum,
    );

    return await _boltz.broadcastLbtcLnSwap(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
      electrum: electrum,
    );
  }

  Future<ChainSwap> _boltzCreateBitcoinToLiquidSwap({
    required String sendWalletId,
    required int amountSat,
    required ElectrumConnection btcElectrum,
    required ElectrumConnection lbtcElectrum,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(2);
      final chainSwap = await _boltz.createBtcToLbtcChainSwap(
        sendWalletId: sendWalletId,
        index: index,
        amountSat: amountSat,
        environment: _environment,
        btcElectrum: btcElectrum,
        lbtcElectrum: lbtcElectrum,
        receiveWalletId: receiveWalletId,
        externalRecipientAddress: externalRecipientAddress,
      );

      return chainSwap.toEntity(
        environment: Environment.fromName(_environment.name),
      ) as ChainSwap;
    });
  }

  Future<ChainSwap> _boltzCreateLiquidToBitcoinSwap({
    required String sendWalletId,
    required int amountSat,
    required ElectrumConnection btcElectrum,
    required ElectrumConnection lbtcElectrum,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    return _withCreationLock(() async {
      final index = await _reserveSwapKeyIndex(2);
      final chainSwap = await _boltz.createLbtcToBtcChainSwap(
        sendWalletId: sendWalletId,
        index: index,
        amountSat: amountSat,
        environment: _environment,
        btcElectrum: btcElectrum,
        lbtcElectrum: lbtcElectrum,
        receiveWalletId: receiveWalletId,
        externalRecipientAddress: externalRecipientAddress,
      );

      return chainSwap.toEntity(
        environment: Environment.fromName(_environment.name),
      ) as ChainSwap;
    });
  }

  Future<String> claimLiquidToBitcoinSwap({
    required String swapId,
    required String bitcoinClaimAddress,
    required int absoluteFees,
    bool cooperate = true,
    ElectrumConnection? electrum,
  }) async {
    _requireEffectAdmission();
    final signedTxHex = await _boltz.claimLbtcToBtcChainSwap(
      swapId: swapId,
      claimBitcoinAddress: bitcoinClaimAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
      counterpartyElectrum: await _electrumConnection(isLiquid: true),
      electrum: electrum,
    );

    return await _boltz.broadcastChainSwapClaim(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
      electrum: electrum,
    );
  }

  Future<String> claimBitcoinToLiquidSwap({
    required String swapId,
    required String liquidClaimAddress,
    required int absoluteFees,
    bool cooperate = true,
    ElectrumConnection? electrum,
  }) async {
    _requireEffectAdmission();
    final signedTxHex = await _boltz.claimBtcToLbtcChainSwap(
      swapId: swapId,
      claimLiquidAddress: liquidClaimAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
      counterpartyElectrum: await _electrumConnection(isLiquid: false),
      electrum: electrum,
    );

    return await _boltz.broadcastChainSwapClaim(
      swapId: swapId,
      signedTxHex: signedTxHex,
      broadcastViaBoltz: false,
      electrum: electrum,
    );
  }

  Future<String> refundBitcoinToLiquidSwap({
    required String swapId,
    required String bitcoinRefundAddress,
    required int absoluteFees,
    bool cooperate = true,
    ElectrumConnection? electrum,
  }) async {
    _requireEffectAdmission();
    final signedTxHex = await _boltz.refundBtcToLbtcChainSwap(
      swapId: swapId,
      refundBitcoinAddress: bitcoinRefundAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
      counterpartyElectrum: await _electrumConnection(isLiquid: true),
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
    _requireEffectAdmission();
    final signedTxHex = await _boltz.refundLbtcToBtcChainSwap(
      swapId: swapId,
      refundLiquidAddress: liquidRefundAddress,
      absoluteFees: absoluteFees,
      tryCooperate: cooperate,
      counterpartyElectrum: await _electrumConnection(isLiquid: false),
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
    return swapModel.toEntity(
      environment: Environment.fromName(_environment.name),
    );
  }

  /// DB-backed: emits current state on listen + every change, so observers
  /// can't miss a terminal update like the old broadcast stream could.
  Stream<Swap> watchSwap({required String swapId}) => _boltz.storage
      .watchSwap(swapId)
      .map(
        (model) => model.toEntity(
          environment: Environment.fromName(_environment.name),
        ),
      );

  Future<Swap> reconcileLockupTxid(Swap swap) async {
    // Only a chain swap missing its lockup txid needs this. Submarine
    // lockups are recorded at broadcast the same way; a reverse swap has no
    // user lockup.
    if (swap is! ChainSwap || swap.sendTxid != null) return swap;
    try {
      // Derived from our own swap secrets (Boltz-free); returns null when no
      // lockup is on chain yet (e.g. a swap created but never funded), which
      // self-gates this to genuinely-broadcast-but-unrecorded swaps.
      final swapObject = await _boltz.storage.fetchChainSwap(swap.id);
      final lockupTxid = await _boltz.chainSwapUserLockupTxid(swapObject);
      if (lockupTxid == null) return swap;
      swapsLog.fine(
        'SWAPS: ${swap.id} lockup txid recovered from chain '
        '(crash-window backfill)',
      );
      // Reuses updatePaidSendSwap: it records sendTxid and only promotes
      // pending->paid, so an already-expired/failed row keeps its status
      // while gaining the sendTxid the refund path requires.
      await updatePaidSendSwap(swapId: swap.id, txid: lockupTxid);
      return await getSwap(swapId: swap.id);
    } catch (e) {
      swapsLog.warning('SWAPS: ${swap.id} lockup-txid backfill skipped: $e');
      return swap;
    }
  }

  Future<void> updatePaidSendSwap({
    required String swapId,
    required String txid,
    int? absoluteFees,
  }) => _boltz.storage.mutate(swapId, () async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity(
      environment: Environment.fromName(_environment.name),
    );
    // check the status before updating it
    // it is possible that the stream updates the status before this method
    // we don't want a status ahead of paid to be updated back to paid
    // Boltz honours only the first transaction to a lockup address, so the
    // first recorded lockup is never replaced by a later one.
    final recorded = switch (swap) {
      LnSendSwap(:final sendTxid) || ChainSwap(:final sendTxid) => sendTxid,
      LnReceiveSwap() => null,
    };
    if (recorded != null && recorded != txid) {
      swapsLog.warning(
        'SWAPS: $swapId already records lockup $recorded; ignoring $txid',
      );
    }
    final lockupTxid = recorded ?? txid;
    final updatedSwap = switch (swap) {
      LnSendSwap() => swap.copyWith(
        sendTxid: lockupTxid,
        pendingLockupTx: null,
        pendingLockupTxid: null,
        status: swap.status == SwapStatus.pending
            ? SwapStatus.paid
            : swap.status,
        fees: absoluteFees != null
            ? swap.fees?.copyWith(lockupFee: absoluteFees)
            : swap.fees,
      ),
      ChainSwap() => swap.copyWith(
        sendTxid: lockupTxid,
        pendingLockupTx: null,
        pendingLockupTxid: null,
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
  });

  Future<Swap> _recordPendingLockup({
    required String swapId,
    required String signedTx,
  }) => _boltz.storage.mutate(swapId, () async {
    final model = await _boltz.storage.fetch(swapId);
    if (model == null) throw SwapsException('swap $swapId not found');
    final swap = model.toEntity(
      environment: Environment.fromName(_environment.name),
    );
    final (lockup, pending) = switch (swap) {
      LnSendSwap(:final sendTxid, :final pendingLockupTx) ||
      ChainSwap(
        :final sendTxid,
        :final pendingLockupTx,
      ) => (sendTxid, pendingLockupTx),
      LnReceiveSwap() => throw SwapsException(
        'reverse swap $swapId has no lockup of ours',
      ),
    };
    if (lockup != null) {
      throw SwapsException('swap $swapId already records a lockup');
    }
    if (pending == signedTx) return swap;
    if (pending != null) {
      throw SwapsException('swap $swapId already has a lockup being confirmed');
    }
    final txid = await _lockupChain.txidOf(
      signedTx: signedTx,
      isLiquid: switch (swap) {
        LnSendSwap() => swap.type == SwapType.liquidToLightning,
        ChainSwap() => swap.type == SwapType.liquidToBitcoin,
        LnReceiveSwap() => false,
      },
    );
    final updated = switch (swap) {
      LnSendSwap() => swap.copyWith(
        pendingLockupTx: signedTx,
        pendingLockupTxid: txid,
      ),
      ChainSwap() => swap.copyWith(
        pendingLockupTx: signedTx,
        pendingLockupTxid: txid,
      ),
      LnReceiveSwap() => swap,
    };
    await _boltz.storage.store(SwapModel.fromEntity(updated));
    return updated;
  });

  Future<void> _dropPendingLockup(String swapId) =>
      _boltz.storage.mutate(swapId, () async {
        final model = await _boltz.storage.fetch(swapId);
        if (model == null) return;
        final updated = switch (model.toEntity(
          environment: Environment.fromName(_environment.name),
        )) {
          final LnSendSwap swap => swap.copyWith(
            pendingLockupTx: null,
            pendingLockupTxid: null,
          ),
          final ChainSwap swap => swap.copyWith(
            pendingLockupTx: null,
            pendingLockupTxid: null,
          ),
          final LnReceiveSwap swap => swap,
        };
        await _boltz.storage.store(SwapModel.fromEntity(updated));
      });

  /// Settles a lockup whose broadcast outcome is unknown, from the user's own
  /// servers: a known txid is recorded; otherwise the identical signed
  /// transaction is rebroadcast, which can never create a second lockup. A
  /// swap that already failed is never funded fresh once the lookup proves
  /// the lockup never went out; without a locally computed txid it is
  /// rebroadcast anyway — either it was out already, or the refund returns
  /// it. Boltz's own status events record the lockup too (see
  /// [SwapStatusMapper]).
  Future<Swap> resolvePendingLockup(Swap swap) async {
    final (pendingTx, pendingTxid, lockupTxid, isLiquid) = switch (swap) {
      LnSendSwap(
        :final pendingLockupTx,
        :final pendingLockupTxid,
        :final sendTxid,
      ) =>
        (
          pendingLockupTx,
          pendingLockupTxid,
          sendTxid,
          swap.type == SwapType.liquidToLightning,
        ),
      ChainSwap(
        :final pendingLockupTx,
        :final pendingLockupTxid,
        :final sendTxid,
      ) =>
        (
          pendingLockupTx,
          pendingLockupTxid,
          sendTxid,
          swap.type == SwapType.liquidToBitcoin,
        ),
      LnReceiveSwap() => (null, null, null, false),
    };
    if (pendingTx == null || lockupTxid != null) return swap;
    try {
      Future<bool> known(String txid) => _lockupChain.isKnown(
        txid: txid,
        signedTx: pendingTx,
        isLiquid: isLiquid,
        environment: _environment,
      );

      Future<Swap> record(String txid) async {
        await updatePaidSendSwap(swapId: swap.id, txid: txid);
        swapsLog.fine('SWAPS: ${swap.id} pending lockup confirmed $txid');
        return getSwap(swapId: swap.id);
      }

      Future<Swap> drop(String reason) async {
        await _dropPendingLockup(swap.id);
        swapsLog.fine('SWAPS: ${swap.id} pending lockup dropped ($reason)');
        return getSwap(swapId: swap.id);
      }

      if (pendingTxid != null) {
        if (await known(pendingTxid)) return await record(pendingTxid);
        // The txid is computed from our own signed lockup: unknown means it
        // never went out, and a swap that already failed is not funded
        // fresh.
        if (swap.status.hasFailed) {
          return await drop('never broadcast; swap ${swap.status.name}');
        }
      }

      _requireEffectAdmission();
      switch (await _lockupChain.broadcast(
        requireAdmission: _requireEffectAdmission,
        signedTx: pendingTx,
        isLiquid: isLiquid,
        environment: _environment,
      )) {
        case LockupAccepted(:final txid):
          return await record(txid);
        case LockupAlreadyInChain():
          if (pendingTxid != null && await known(pendingTxid)) {
            return await record(pendingTxid);
          }
          return swap;
        case LockupRejected():
          if (pendingTxid != null && await known(pendingTxid)) {
            return await record(pendingTxid);
          }
          return await drop('rejected by the node');
        case LockupOutcomeUnknown():
          return swap;
      }
    } catch (e) {
      if (e is SwapsBusyFailure || e is SwapsAuthorizationFailure) rethrow;
      swapsLog.warning(
        'SWAPS: ${swap.id} pending lockup not settled (${e.runtimeType})',
      );
      return swap;
    }
  }

  Future<Swap> updateSendSwapLockupFees({
    required String swapId,
    required int lockupFees,
  }) => _boltz.storage.mutate(swapId, () async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw "No swap model found";
    }

    final swap = swapModel.toEntity(
      environment: Environment.fromName(_environment.name),
    );
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
  });

  /// PRIVATE
  Future<void> _updateCompletedSendSwap({required String swapId}) =>
      _boltz.storage.mutate(swapId, () async {
        final swapModel = await _boltz.storage.fetch(swapId);
        if (swapModel == null) {
          throw "No swap model found";
        }

        final swap = swapModel.toEntity(
          environment: Environment.fromName(_environment.name),
        );
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
      });

  /// Binds the swap master key to [walletFingerprint] for reads and reports
  /// whether it already exists — cheap, so the caller can skip decrypting the
  /// wallet seed when the key is already present.
  Future<bool> swapMasterKeyReady({required String walletFingerprint}) =>
      _boltz.swapMasterKeyReady(
        walletFingerprint: walletFingerprint,
        environment: _environment,
      );

  /// Persists a swap master key the app's secrets layer derived. Called once,
  /// only when [swapMasterKeyReady] reported a miss, so swap creation and
  /// restore READ the key from storage and never derive lazily.
  Future<void> storeSwapMasterKey(DerivedSwapMasterKey key) =>
      _boltz.storeSwapMasterKey(key: key, environment: _environment);

  /// What the seed viewer shows about the swap master key for
  /// [walletFingerprint]; null when none is stored. Carries no words — see
  /// the sealed recovery widget.
  Future<SwapMasterKeyInfo?> getSwapMasterKeyInfo({
    required String walletFingerprint,
  }) async {
    final model = await _boltz.getSwapMasterKeyForWallet(
      walletFingerprint: walletFingerprint,
      environment: _environment,
    );
    if (model == null) return null;
    return SwapMasterKeyInfo(
      fingerprint: model.fingerprint,
      walletFingerprint: walletFingerprint,
      network: model.network,
    );
  }

  // Reverse and submarine swaps consume 1 index; chain swaps consume 2 (boltz
  // derives the refund key at `index` and the claim key at `index + 1`).
  Future<int> _reserveSwapKeyIndex(int count) async {
    final swapMasterKey = await _boltz.getSwapMasterKey(
      environment: _environment,
    );
    // The index counter is keyed by the swap master key's OWN fingerprint —
    // NOT the default wallet's fingerprint (which keys the master key blob).
    // Both are 1:1 with the seed, so they stay consistent.
    final stored = await _boltz.storage.getSwapKeyIndex(
      swapMasterKey.fingerprint,
    );
    // Local collision floor, re-checked on EVERY reservation: a rescue
    // imports swaps at their original indices without advancing this
    // counter, so the counter alone can lag behind a rescued swap and hand
    // out an in-use index (the keyIndex-reuse bug). Only rescued swaps
    // count: swaps from before 6.12 were derived from the wallet seed, not
    // this key, and their indices would push new swaps past the range
    // Boltz's gap-limited restore scans. Chain swaps occupy two indices.
    var localHighest = -1;
    for (final swap in await getAllSwaps()) {
      if (!swap.recovered) continue;
      final top = swap is ChainSwap ? swap.keyIndex + 1 : swap.keyIndex;
      if (top > localHighest) localHighest = top;
    }
    final int seedFloor;
    if (stored == null) {
      // Also seed past boltz's highest known index (-1 when none) so a new
      // swap can't re-derive an in-use key on a recovered seed. Boltz's
      // restore endpoint is gap-limited and can under-report, hence the
      // local floor above still applies.
      final highest = await _boltz.restoreSwapIndex(
        swapMasterKey: swapMasterKey,
      );
      seedFloor = highest + 1;
    } else {
      seedFloor = stored;
    }
    final floor = seedFloor > localHighest + 1 ? seedFloor : localHighest + 1;
    final current = await _boltz.storage.reserveSwapKeyIndex(
      swapMasterKey.fingerprint,
      count,
      floor,
    );
    swapsLog.fine(
      'SWAP_KEY: reserved index $current (count=$count) '
      'fp=${swapMasterKey.fingerprint}',
    );
    return current;
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
    // claim/refund tx (un-wedging a mis-settled swap) needs an explicit flag.
    bool clearReceiveTxid = false,
    bool clearRefundTxid = false,
  }) => _boltz.storage.mutate(swapId, () async {
    final swapModel = await _boltz.storage.fetch(swapId);
    if (swapModel == null) {
      throw 'No swap model found';
    }
    final swap = swapModel.toEntity(
      environment: Environment.fromName(_environment.name),
    );
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
        refundTxid: clearRefundTxid ? null : refundTxid ?? swap.refundTxid,
        refundAddress: refundAddress ?? swap.refundAddress,
        preimage: preimage ?? swap.preimage,
        completionTime: completionTime ?? swap.completionTime,
        fees: fees,
      ),
      ChainSwap() => swap.copyWith(
        status: status ?? swap.status,
        receiveTxid: clearReceiveTxid ? null : receiveTxid ?? swap.receiveTxid,
        refundTxid: clearRefundTxid ? null : refundTxid ?? swap.refundTxid,
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
      '${clearRefundTxid ? ' refundTxid=CLEARED' : ''}'
      '${refundFee != null ? ' refundFee=$refundFee' : ''}'
      '${completionTime != null ? ' completed' : ''}',
    );

    await _boltz.storage.store(SwapModel.fromEntity(updated));
    return updated;
  });

  Future<int> getSwapClaimTxSize({
    required String swapId,
    required SwapType swapType,
    bool isCooperative = true,
    String? claimAddressForChainSwaps,
    ElectrumConnection? electrum,
  }) async {
    switch (swapType) {
      case SwapType.lightningToBitcoin:
        return await _boltz.getBtcLnClaimTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
          electrum: electrum,
        );
      case SwapType.lightningToLiquid:
        return await _boltz.getLbtcLnClaimTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
          electrum: electrum,
        );
      case SwapType.liquidToBitcoin:
      case SwapType.bitcoinToLiquid:
        return await _boltz.getChainClaimTxSize(
          swapId: swapId,
          claimAddress: claimAddressForChainSwaps!,
          isCooperative: isCooperative,
          counterpartyElectrum: await _electrumConnection(
            isLiquid: swapType == SwapType.liquidToBitcoin,
          ),
          electrum: electrum,
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

  void unsubscribeFromSwaps(List<String> swapIds) {
    _boltz.unsubscribeToSwaps(swapIds);
  }

  void subscribeToSwaps(List<String> swapIds) {
    _boltz.subscribeToSwaps(swapIds);
  }

  Future<List<Swap>> getOngoingSwaps({String? walletId}) async {
    final allSwapModels = await _boltz.storage.fetchAll(
      isTestnet: _environment == NetworkEnv.regtest
          ? null
          : _environment == NetworkEnv.testnet,
    );

    final allSwaps = allSwapModels
        .map(
          (swapModel) => swapModel.toEntity(
            environment: Environment.fromName(_environment.name),
          ),
        )
        .toList();
    // Still in flight, holding a lockup whose broadcast is being confirmed,
    // or holding funds that must be claimed or refunded.
    bool needsWatching(Swap swap) =>
        swap.status == SwapStatus.pending ||
        swap.status == SwapStatus.paid ||
        swap.hasPendingLockup ||
        swap.nextAction != SwapAction.none;

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
      isTestnet: _environment == NetworkEnv.regtest
          ? null
          : _environment == NetworkEnv.testnet,
    );
    final allSwaps = allSwapModels
        .map(
          (swapModel) => swapModel.toEntity(
            environment: Environment.fromName(_environment.name),
          ),
        )
        .toList();
    return allSwaps;
  }

  /// Restores all swaps derivable from the dedicated swap master key via Boltz,
  /// across BTC-LN, LBTC-LN and chain. Identification only (Phase 1); importing
  /// them into local storage is handled separately.
  Future<List<RestoredSwap>> restoreSwaps({
    required NetworkEnv environment,
  }) async {
    if (environment != _environment) {
      throw SwapsException('Restore network does not match its engine');
    }
    final swapMasterKey = await _boltz.getSwapMasterKey(
      environment: environment,
    );
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
          environment: _environment,
          id: s.id,
          kind: _restoredKind(s.kind),
          status: _restoreStatusToSwapStatus(s.status, kind: s.kind),
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
  /// `is_resolved()` plus Boltz's own lockup records — Boltz's word, not the
  /// chain's. Boltz's verdict is the default, with one safety-floor
  /// override: a chain swap in a `*.refunded` status only proves Boltz
  /// refunded its OWN lockup — ours may still sit unspent on the sending
  /// chain — so it stays rescuable; if the user lockup turns out spent, the
  /// refund attempt learns that on-chain instead of the swap being hidden
  /// from rescue.
  ///
  /// TODO: replace the status floor with an on-chain check of the user
  /// lockup's outspends once boltz-dart exposes an electrum-backed report
  /// (the current one rides third-party mempool REST — a privacy violation
  /// on custom-electrum setups, and it hangs on dead testnet explorers).
  bool _restoredRecoverable(boltz.RestoredSwapSummary s) {
    final overridden =
        !s.recoverable &&
        s.kind == boltz.SwapType.chain &&
        (s.status == 'transaction.refunded' || s.status == 'swap.refunded');
    swapsLog.fine(
      'SWAP_RESTORE: summary ${s.id} kind=${s.kind.name} '
      'boltzStatus=${s.status} recoverable=${overridden || s.recoverable} '
      '(${overridden ? 'chain refunded floor' : 'boltz'}) '
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
  SwapStatus _restoreStatusToSwapStatus(
    String boltzStatus, {
    required boltz.SwapType kind,
  }) {
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
      // Boltz's lockup on a reverse swap, but OUR lockup on a submarine or
      // chain swap: funds in flight, nothing for us to claim.
      case 'transaction.mempool':
      case 'transaction.confirmed':
        return kind == boltz.SwapType.reverse
            ? SwapStatus.claimable
            : SwapStatus.paid;
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
    if (restored.environment != _environment) {
      throw SwapsException('Restored swap belongs to another network');
    }

    final swapMasterKey = await _boltz.getSwapMasterKey(
      environment: _environment,
    );
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
            isTestnet: _environment == NetworkEnv.testnet,
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
            isTestnet: _environment == NetworkEnv.testnet,
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
            isTestnet: _environment == NetworkEnv.testnet,
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
            isTestnet: _environment == NetworkEnv.testnet,
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
          isTestnet: _environment == NetworkEnv.testnet,
          keyIndex: obj.refundIndex.toInt(),
          creationTime: creationTime,
          sendWalletId: sendWalletId,
          receiveWalletId: receiveWalletId,
          sendTxid: lockupTxid,
          paymentAddress: obj.scriptAddress,
          paymentAmount: obj.outAmount.toInt(),
        );
    }

    // Same per-swap lock as every other writer, so this store can't land in
    // the middle of a concurrent fetch-merge-store of the same swap. An
    // existing row keeps what it recorded; the rescue only fills the rest.
    final stored = await _boltz.storage.mutate(model.id, () async {
      final existing = await _boltz.storage.fetch(model.id);
      final merged = existing == null
          ? model
          : mergeRescuedSwap(existing, model);
      await _boltz.storage.store(merged);
      return merged;
    });
    subscribeToSwaps([id]);
    await reconcileSwaps([id]);
    swapsLog.fine('SWAP_RESTORE: rescued $id as ${stored.runtimeType}');
    return stored.toEntity(
      environment: Environment.fromName(_environment.name),
    );
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

  Future<Swap?> byTxId(String txId) async {
    final swapModel = await _boltz.storage.fetchByTxId(txId);
    if (swapModel == null) {
      return null; // No swap found for the given txId
    }
    return swapModel.toEntity(
      environment: Environment.fromName(_environment.name),
    );
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

  Future<SwapLimits> limits(SwapType type) async {
    final (limits, _) = await getSwapLimitsAndFees(type);
    return limits;
  }

  Future<void> markLockupBroadcast({
    required String swapId,
    required String txid,
    int? lockupFeeSat,
  }) => updatePaidSendSwap(
    swapId: swapId,
    txid: txid,
    absoluteFees: lockupFeeSat,
  );

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
      final swap = swapModel.toEntity(
        environment: Environment.fromName(_environment.name),
      );
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
          electrum: electrum,
        );
      case SwapType.bitcoinToLightning:
        return await _boltz.getBtcLnRefundTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
          electrum: electrum,
        );
      case SwapType.liquidToBitcoin:
      case SwapType.bitcoinToLiquid:
        return await _boltz.getChainRefundTxSize(
          swapId: swapId,
          isCooperative: isCooperative,
          refundAddress: refundAddressForChainSwaps!,
          counterpartyElectrum: await _electrumConnection(
            isLiquid: swapType == SwapType.bitcoinToLiquid,
          ),
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
    final wallets = await _wallets(environment: _environment);
    for (final w in wallets) {
      if (w.isDefault && !w.isLiquid && w.fingerprint.isNotEmpty) {
        return w.fingerprint;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // SwapResolver and BoltzSwaps
  // ---------------------------------------------------------------------

  /// Runs [action] and reduces a failure to a [SwapsFailure]. Programmer
  /// errors (`Error`) are not failures and propagate.
  Future<Result<T, SwapsFailure>> _guard<T>(
    Future<T> Function() action, {
    SwapsFailure Function(Object error) classify = classifySwapsFailure,
  }) async {
    try {
      return Ok(await action());
    } catch (e) {
      if (e is Error) rethrow;
      return Err(classify(e));
    }
  }

  Future<Result<T, SwapsFailure>> _guardResult<T>(
    Future<Result<T, SwapsFailure>> Function() action, {
    SwapsFailure Function(Object error) classify = classifySwapsFailure,
  }) async {
    return (await _guard(
      action,
      classify: classify,
    )).fold((result) => result, (failure) => Err(failure));
  }

  @override
  NetworkEnv get environment => _environment;

  @override
  bool get isTestnet => _environment == NetworkEnv.testnet;

  @override
  Stream<Swap> get updates => swapUpdatesStream;

  @override
  void listen(List<String> swapIds) => subscribeToSwaps(swapIds);

  @override
  Future<Result<void, SwapsFailure>> reconcile(List<String> swapIds) =>
      _guard(() => reconcileSwaps(swapIds));

  @override
  Future<Result<Swap, SwapsFailure>> resolve(
    Swap swap,
  ) => _guardResult(() async {
    _requireEffectAdmission();
    var current = await getSwap(swapId: swap.id);
    current = await resolvePendingLockup(current);
    current = await reconcileLockupTxid(current);
    final Result<Object?, SwapsFailure>? action = switch (current.nextAction) {
      SwapAction.claim => await _orTimeoutRefund(current, () => claim(current)),
      SwapAction.refund => await refund(current),
      SwapAction.coopSign => await _orTimeoutRefund(current, () async {
        await coopSign(current);
        return const Ok(null);
      }),
      SwapAction.none when await _settleOnEvidence(current) => const Ok(null),
      SwapAction.none when current.awaitsTimeoutRefund(DateTime.now()) =>
        await refund(current, scriptPathOnly: true),
      SwapAction.none => null,
    };
    return switch (action) {
      Err(:final failure) => Err(failure),
      Ok() => Ok(await getSwap(swapId: current.id)),
      null => Ok(current),
    };
  });

  /// Runs [action]; when it fails on a swap still holding our lockup a day
  /// later, falls back to the script-path refund, which the chain refuses
  /// until our timelock passes.
  Future<Result<Object?, SwapsFailure>> _orTimeoutRefund(
    Swap swap,
    Future<Result<Object?, SwapsFailure>> Function() action,
  ) async {
    final Result<Object?, SwapsFailure> result;
    try {
      result = await action();
    } catch (error) {
      if (error is SwapsFailure) rethrow;
      if (!swap.awaitsTimeoutRefund(DateTime.now())) rethrow;
      return refund(swap, scriptPathOnly: true);
    }
    // Address lookup failures used to enter the same timeout fallback as
    // the legacy exception path. Keep that decision when they are typed.
    if (result is Err && swap.awaitsTimeoutRefund(DateTime.now())) {
      return refund(swap, scriptPathOnly: true);
    }
    return result;
  }

  /// The id of another stored swap that already records [txid], if any.
  Future<String?> _swapRecordingTxid(
    String txid, {
    required String except,
  }) async {
    for (final swap in await getAllSwaps()) {
      if (swap.id == except) continue;
      final recorded = switch (swap) {
        LnReceiveSwap(:final receiveTxid) => [receiveTxid],
        LnSendSwap(:final sendTxid, :final refundTxid) => [
          sendTxid,
          refundTxid,
        ],
        ChainSwap(:final sendTxid, :final receiveTxid, :final refundTxid) => [
          sendTxid,
          receiveTxid,
          refundTxid,
        ],
      };
      if (recorded.contains(txid)) return swap.id;
    }
    return null;
  }

  /// Completes a swap Boltz reported settled once our own evidence agrees: a
  /// send on a preimage that hashes to the invoice's payment hash, a direct
  /// payment on its incoming transaction in the receiving wallet (and on no
  /// other swap). Returns whether the swap was completed.
  Future<bool> _settleOnEvidence(Swap swap) async {
    switch (swap) {
      case LnSendSwap(
        status: SwapStatus.paid,
        :final sendTxid?,
        :final invoice,
      ):
        final String? preimage;
        try {
          preimage =
              swap.preimage ?? await getSendSwapPreimage(swapId: swap.id);
        } catch (_) {
          return false;
        }
        if (preimage == null ||
            !preimageMatchesInvoice(preimage: preimage, invoice: invoice)) {
          return false;
        }
        await updateSwapFields(
          swap.id,
          preimage: preimage,
          status: SwapStatus.completed,
          completionTime: DateTime.now(),
        );
        swapsLog.fine(
          'SWAPS: ${swap.id} completed on a verified preimage '
          '(lockup $sendTxid)',
        );
        return true;
      case LnReceiveSwap(
        status: SwapStatus.paid,
        wasDirectPayment: true,
        :final receiveTxid?,
        :final receiveWalletId,
      ):
        final txs = await _walletTxs(receiveWalletId);
        if (txs == null) return false;
        final tx = txs.where((tx) => tx.txId == receiveTxid).firstOrNull;
        if (tx == null || !tx.isIncoming) return false;
        final recordedOn = await _swapRecordingTxid(
          receiveTxid,
          except: swap.id,
        );
        if (recordedOn != null) {
          swapsLog.warning(
            'SWAPS: ${swap.id} direct payment $receiveTxid already belongs '
            'to swap $recordedOn — ignoring',
          );
          return false;
        }
        await updateSwapFields(
          swap.id,
          status: SwapStatus.completed,
          completionTime: DateTime.now(),
        );
        swapsLog.fine(
          'SWAPS: ${swap.id} direct payment $receiveTxid seen in the wallet',
        );
        return true;
      default:
        return false;
    }
  }

  @override
  Future<Result<Swap, SwapsFailure>> resolveScriptPath(Swap swap) =>
      _guardResult(() async {
        _requireEffectAdmission();
        final current = await getSwap(swapId: swap.id);
        final action = switch (current.nextAction) {
          SwapAction.claim => await claim(current, scriptPathOnly: true),
          SwapAction.refund => await refund(current, scriptPathOnly: true),
          SwapAction.none when current.awaitsTimeoutRefund(DateTime.now()) =>
            await refund(current, scriptPathOnly: true),
          SwapAction.coopSign || SwapAction.none => null,
        };
        return switch (action) {
          Err(:final failure) => Err(failure),
          Ok() => Ok(await getSwap(swapId: current.id)),
          null => Ok(current),
        };
      });

  @override
  Future<Result<void, SwapsFailure>> verifyCompletions() =>
      _guard(_verifyCompletions);

  @override
  Future<Result<Swap, SwapsFailure>> recordPendingLockup({
    required String swapId,
    required String signedTx,
  }) => _guard(() => _recordPendingLockup(swapId: swapId, signedTx: signedTx));

  @override
  Future<Result<void, SwapsFailure>> dropPendingLockup(String swapId) =>
      _guard(() => _dropPendingLockup(swapId));

  @override
  Future<Result<Swap, SwapsFailure>> recordLockup({
    required String swapId,
    required String txid,
    int? lockupFeeSat,
  }) => _guard(() async {
    await updatePaidSendSwap(
      swapId: swapId,
      txid: txid,
      absoluteFees: lockupFeeSat,
    );
    return getSwap(swapId: swapId);
  });

  @override
  Future<Result<List<RestoredSwap>, SwapsFailure>> restore() =>
      _guard(_restore);

  @override
  Future<Result<Swap, SwapsFailure>> rescue(
    RestoredSwap restored, {
    required String walletId,
  }) => _guard(() => _rescue(restored, walletId: walletId));

  @override
  Future<Result<(SwapLimits, SwapFees), SwapsFailure>> limitsAndFees(
    SwapType type,
  ) => _guard(
    () => getSwapLimitsAndFees(type),
    classify: classifySwapCreationFailure,
  );

  @override
  Future<Result<void, SwapsFailure>> checkServer() => _guard(
    () => _boltz.updateFees(swapType: SwapType.bitcoinToLightning),
    classify: classifySwapCreationFailure,
  );

  Future<ElectrumConnection> _electrumConnection({required bool isLiquid}) =>
      _electrum.run(
        isLiquid: isLiquid,
        environment: _environment,
        operation: (connection) async => connection,
      );

  Future<String> _electrumUrl({required bool isLiquid}) async =>
      (await _electrumConnection(isLiquid: isLiquid)).url;

  /// Refuses a wallet that is unknown or not on [isLiquid]'s chain, before
  /// anything is created.
  Future<void> _requireWallet(String walletId, {required bool isLiquid}) async {
    final wallets = await _wallets(environment: _environment);
    final wallet = wallets.where((w) => w.id == walletId).firstOrNull;
    if (wallet == null || wallet.isLiquid != isLiquid) {
      throw SwapsException(
        'wallet is not a ${isLiquid ? 'Liquid' : 'Bitcoin'} wallet here',
      );
    }
  }

  Future<void> _requireWithinLimits(SwapType type, int amountSat) async {
    final (limits, _) = await getSwapLimitsAndFees(type);
    if (!limits.accepts(amountSat)) {
      throw SwapsAmountOutOfLimitsException(
        minSat: limits.min,
        maxSat: limits.max,
      );
    }
  }

  @override
  Future<Result<LnReceiveSwap, SwapsFailure>> createLightningToBitcoinSwap({
    required String walletId,
    required int amountSat,
    String? description,
  }) => _createLightningReceive(
    type: SwapType.lightningToBitcoin,
    walletId: walletId,
    amountSat: amountSat,
    description: description,
  );

  @override
  Future<Result<LnReceiveSwap, SwapsFailure>> createLightningToLiquidSwap({
    required String walletId,
    required int amountSat,
    String? description,
  }) => _createLightningReceive(
    type: SwapType.lightningToLiquid,
    walletId: walletId,
    amountSat: amountSat,
    description: description,
  );

  Future<Result<LnReceiveSwap, SwapsFailure>> _createLightningReceive({
    required SwapType type,
    required String walletId,
    required int amountSat,
    String? description,
  }) => _guardResult(() async {
    final toLiquid = type == SwapType.lightningToLiquid;
    await _requireWallet(walletId, isLiquid: toLiquid);
    await _requireWithinLimits(type, amountSat);
    await _ensureMasterKey();
    final electrum = await _electrumConnection(isLiquid: toLiquid);
    final String claimAddress;
    switch (await _newAddressFor(walletId)) {
      case Ok(:final value):
        claimAddress = value;
      case Err(:final failure):
        return Err(failure);
    }
    return Ok(
      await _created(
        toLiquid
            ? _boltzCreateLightningToLiquidSwap(
                walletId: walletId,
                amountSat: amountSat,
                electrum: electrum,
                claimAddress: claimAddress,
                description: description,
              )
            : _boltzCreateLightningToBitcoinSwap(
                walletId: walletId,
                amountSat: amountSat,
                electrum: electrum,
                claimAddress: claimAddress,
                description: description,
              ),
      ),
    );
  }, classify: classifySwapCreationFailure);

  @override
  Future<Result<LnSendSwap, SwapsFailure>> createBitcoinToLightningSwap({
    required String walletId,
    required String invoice,
  }) => _createLightningSend(
    type: SwapType.bitcoinToLightning,
    walletId: walletId,
    invoice: invoice,
  );

  @override
  Future<Result<LnSendSwap, SwapsFailure>> createLiquidToLightningSwap({
    required String walletId,
    required String invoice,
  }) => _createLightningSend(
    type: SwapType.liquidToLightning,
    walletId: walletId,
    invoice: invoice,
  );

  Future<Result<LnSendSwap, SwapsFailure>> _createLightningSend({
    required SwapType type,
    required String walletId,
    required String invoice,
  }) => _guard(() async {
    final fromLiquid = type == SwapType.liquidToLightning;
    await _requireWallet(walletId, isLiquid: fromLiquid);
    // Boltz refuses a second swap for the same invoice: reuse ours while
    // nothing was locked into it, and refuse while one is in progress.
    final pending = await getSendSwapByInvoice(
      invoice: invoice,
      walletId: walletId,
      type: type,
    );
    if (pending != null) {
      await reconcileSwaps([pending.id]);
      final current = await getSwap(swapId: pending.id);
      if (current is LnSendSwap &&
          current.status == SwapStatus.pending &&
          current.sendTxid == null &&
          !current.hasPendingLockup) {
        return current;
      }
      throw const SwapInProgressException();
    }
    final decoded = await decodeInvoice(invoice: invoice);
    await _requireWithinLimits(type, decoded.sats);
    await _ensureMasterKey();
    final electrum = await _electrumConnection(isLiquid: fromLiquid);
    return _created(
      fromLiquid
          ? _boltzCreateLiquidToLightningSwap(
              walletId: walletId,
              invoice: invoice,
              electrum: electrum,
            )
          : _boltzCreateBitcoinToLightningSwap(
              walletId: walletId,
              invoice: invoice,
              electrum: electrum,
            ),
    );
  }, classify: classifySwapCreationFailure);

  @override
  Future<Result<ChainSwap, SwapsFailure>> createBitcoinToLiquidSwap({
    required String sendWalletId,
    required int amountSat,
    required ChainSwapDestination destination,
  }) => _createChain(
    type: SwapType.bitcoinToLiquid,
    sendWalletId: sendWalletId,
    amountSat: amountSat,
    destination: destination,
  );

  @override
  Future<Result<ChainSwap, SwapsFailure>> createLiquidToBitcoinSwap({
    required String sendWalletId,
    required int amountSat,
    required ChainSwapDestination destination,
  }) => _createChain(
    type: SwapType.liquidToBitcoin,
    sendWalletId: sendWalletId,
    amountSat: amountSat,
    destination: destination,
  );

  Future<Result<ChainSwap, SwapsFailure>> _createChain({
    required SwapType type,
    required String sendWalletId,
    required int amountSat,
    required ChainSwapDestination destination,
  }) => _guard(() async {
    final fromLiquid = type == SwapType.liquidToBitcoin;
    await _requireWallet(sendWalletId, isLiquid: fromLiquid);
    if (destination case ToWallet(:final walletId)) {
      await _requireWallet(walletId, isLiquid: !fromLiquid);
    }
    await _requireWithinLimits(type, amountSat);
    await _ensureMasterKey();
    final btcElectrum = await _electrumConnection(isLiquid: false);
    final lbtcElectrum = await _electrumConnection(isLiquid: true);
    final (receiveWalletId, externalRecipientAddress) = switch (destination) {
      ToWallet(:final walletId) => (walletId, null),
      ToAddress(:final address) => (null, address),
    };
    return _created(
      fromLiquid
          ? _boltzCreateLiquidToBitcoinSwap(
              sendWalletId: sendWalletId,
              amountSat: amountSat,
              btcElectrum: btcElectrum,
              lbtcElectrum: lbtcElectrum,
              receiveWalletId: receiveWalletId,
              externalRecipientAddress: externalRecipientAddress,
            )
          : _boltzCreateBitcoinToLiquidSwap(
              sendWalletId: sendWalletId,
              amountSat: amountSat,
              btcElectrum: btcElectrum,
              lbtcElectrum: lbtcElectrum,
              receiveWalletId: receiveWalletId,
              externalRecipientAddress: externalRecipientAddress,
            ),
    );
  }, classify: classifySwapCreationFailure);

  Future<T> _created<T extends Swap>(Future<T> creation) async {
    final swap = await creation;
    swapsLog.fine(
      'SWAPS: created ${swap.id} ${swap.type.name} keyIndex=${swap.keyIndex}',
    );
    return swap;
  }

  @override
  Future<Result<SwapMasterKeyInfo?, SwapsFailure>> masterKeyInfo() =>
      _guard(() async {
        final fingerprint = await defaultBitcoinFingerprint();
        if (fingerprint == null) return null;
        return getSwapMasterKeyInfo(walletFingerprint: fingerprint);
      }, classify: _classifyMasterKeyFailure);

  @override
  Widget masterKeyView({
    required SwapMasterKeyInfo key,
    required TextStyle style,
    required Widget failure,
  }) => SwapMnemonicView(
    identity: (key.network, key.walletFingerprint, key.fingerprint),
    style: style,
    failure: failure,
    readWords: () => _guard(() async {
      final current = await _boltz.getSwapMasterKeyForWallet(
        walletFingerprint: key.walletFingerprint,
        environment: _environment,
      );
      if (current == null ||
          current.network != key.network ||
          current.fingerprint != key.fingerprint) {
        return null;
      }
      return current.mnemonic;
    }, classify: _classifyMasterKeyFailure),
  );

  @override
  Future<Result<void, SwapsFailure>> deleteMasterKey(
    SwapMasterKeyInfo key,
  ) async {
    if (key.network != _environment.name) {
      return const Err(SwapsMasterKeyUnavailableFailure());
    }
    final result = await _guard(
      () => _boltz.deleteConfirmedSwapMasterKey(
        walletFingerprint: key.walletFingerprint,
        keyFingerprint: key.fingerprint,
        environment: _environment,
      ),
      classify: _classifyMasterKeyFailure,
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(value: true) => const Ok(null),
      Ok(value: false) => const Err(SwapsMasterKeyUnavailableFailure()),
    };
  }

  static SwapsFailure _classifyMasterKeyFailure(Object error) =>
      switch (error) {
        SwapsException(message: 'Swap key network does not match its engine') =>
          const SwapsMasterKeyUnavailableFailure(
            'Swap key network does not match its engine',
          ),
        _ => const SwapsMasterKeyUnavailableFailure(),
      };

  // RESOLVE OPERATIONS — the watcher's verbs. Each resolves its own
  // address, estimates fees (floored at relay minimum, capped at half the
  // swap amount), tries the cooperative path first and falls back to the
  // script path, walks the app's electrum servers, and records the outcome.

  Future<Result<String, SwapsFailure>> claim(
    Swap swap, {
    bool scriptPathOnly = false,
  }) async {
    final stored = await getSwap(swapId: swap.id);
    final existing = switch (stored) {
      LnReceiveSwap(:final receiveTxid) => receiveTxid,
      ChainSwap(:final receiveTxid) => receiveTxid,
      LnSendSwap() => throw SwapsException(
        'submarine swap ${swap.id} is refunded or coop-signed, never claimed',
      ),
    };
    if (existing != null) return Ok(existing);
    if (swap is LnReceiveSwap && swap.wasDirectPayment) {
      // Paid directly on-chain via MRH — there is nothing to claim and no
      // claim txid to report; an empty-string "txid" would only mislead.
      throw SwapsException(
        'swap ${swap.id} was a direct payment — nothing to claim',
      );
    }

    final String claimAddress;
    switch (await _resolveClaimAddress(swap)) {
      case Ok(:final value):
        claimAddress = value;
      case Err(:final failure):
        return Err(failure);
    }
    final claimOnLiquid = switch (swap) {
      LnReceiveSwap() => swap.type == SwapType.lightningToLiquid,
      ChainSwap() => swap.type == SwapType.bitcoinToLiquid,
      LnSendSwap() => false,
    };

    try {
      final txid = await _electrum.run(
        isLiquid: claimOnLiquid,
        environment: _environment,
        isTransient: _isServerFailure,
        operation: (connection) async {
          // A claim always pays the live (fastest) estimate: one that sits
          // unconfirmed can lose the swap at its timeout. The user saw and
          // accepted the fee cost on the confirm screen. The stored
          // creation-time claimFee is only the fallback when no live estimate
          // can be made, and a stored value above the half-amount burn cap is
          // an untrustworthy server quote and is never used.
          final storedClaimFee = swap.fees?.claimFee;
          final amountSat = _amountSatOrNull(swap);
          final feeCap = amountSat != null && amountSat > 0
              ? amountSat ~/ 2
              : null;
          final storedFee =
              storedClaimFee != null &&
                  storedClaimFee > 0 &&
                  (feeCap == null || storedClaimFee <= feeCap)
              ? storedClaimFee
              : null;

          Future<int> sizedFee({required bool cooperative}) async =>
              _resolveFees(
                txSize: await getSwapClaimTxSize(
                  swapId: swap.id,
                  swapType: swap.type,
                  isCooperative: cooperative,
                  claimAddressForChainSwaps: swap is ChainSwap
                      ? claimAddress
                      : null,
                  electrum: connection,
                ),
                isLiquid: claimOnLiquid,
                amountSat: amountSat,
              );

          // Cooperative sizing round-trips Boltz and can fail (notably for
          // rescued swaps); the script-path size is computed locally, so try
          // that next.
          Future<int> feesFor({required bool cooperative}) async {
            try {
              if (!cooperative) return await sizedFee(cooperative: false);
              try {
                return await sizedFee(cooperative: true);
              } catch (_) {
                return await sizedFee(cooperative: false);
              }
            } catch (e) {
              if (e is SwapsFailure) rethrow;
              if (storedFee == null) rethrow;
              swapsLog.warning(
                'SWAPS: live claim fee unavailable for ${swap.id} '
                '(${_errorMessage(e)}); using the stored fee',
              );
              return storedFee;
            }
          }

          String txid;
          int absoluteFees;
          if (scriptPathOnly) {
            // Zero-Boltz retry: cooperative signing requests Boltz's partial
            // signature, so go straight to the script path.
            absoluteFees = await feesFor(cooperative: false);
            unsubscribeFromSwaps([swap.id]);
            txid = await _broadcastClaim(
              swap,
              claimAddress: claimAddress,
              absoluteFees: absoluteFees,
              cooperate: false,
              electrum: connection,
            );
          } else {
            absoluteFees = await feesFor(cooperative: true);
            unsubscribeFromSwaps([swap.id]);
            try {
              txid = await _broadcastClaim(
                swap,
                claimAddress: claimAddress,
                absoluteFees: absoluteFees,
                cooperate: true,
                electrum: connection,
              );
            } catch (e) {
              if (e is SwapsFailure) rethrow;
              // A cooperative failure can carry text Boltz wrote, after it
              // was sent the preimage. Only the script path, which never
              // asks Boltz, may conclude that the lockup is not there.
              if (_isLockupNotVisible(e)) {
                swapsLog.fine(
                  'SWAPS: coop claim for ${swap.id} reports no lockup; '
                  'checking on the script path',
                );
              } else {
                swapsLog.severe(
                  'SWAPS: coop claim failed for ${swap.id} '
                  '(${_errorMessage(e)}); trying script path',
                  error: e,
                );
              }
              // The script-path claim is a larger transaction: price it on
              // its own size so it does not go out under the rate.
              absoluteFees = await feesFor(cooperative: false);
              txid = await _broadcastClaim(
                swap,
                claimAddress: claimAddress,
                absoluteFees: absoluteFees,
                cooperate: false,
                electrum: connection,
              );
            }
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
      return Ok(txid);
    } catch (e) {
      if (e is SwapsFailure) rethrow;
      if (_isLockupNotVisible(e)) {
        swapsLog.fine(
          'SWAPS: claim for ${swap.id} found no lockup on the electrum server',
        );
      }
      // The script-path-only (zero-Boltz) retry must not fall back to the
      // outspend recovery or re-subscribe over the Boltz websocket, both of
      // which contact the Boltz API. Surface the failure.
      if (scriptPathOnly) {
        await swapsLog.flush();
        throw SwapsException(
          'claim failed for ${swap.id}: ${_errorMessage(e)}',
        );
      }
      final recovered = await _recoverFromVerifiedOutspend(swap, isClaim: true);
      await swapsLog.flush();
      if (recovered != null) return Ok(recovered);
      listen([swap.id]);
      throw SwapsException('claim failed for ${swap.id}: ${_errorMessage(e)}');
    }
  }

  Future<Result<String, SwapsFailure>> refund(
    Swap swap, {
    bool scriptPathOnly = false,
  }) async {
    final stored = await getSwap(swapId: swap.id);
    final existing = switch (stored) {
      ChainSwap(:final refundTxid) => refundTxid,
      LnSendSwap(:final refundTxid) => refundTxid,
      LnReceiveSwap() => throw SwapsException(
        'reverse swap ${swap.id} is claimed, never refunded',
      ),
    };
    if (existing != null) return Ok(existing);

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
    final knownAddress = switch (swap) {
      ChainSwap() => swap.refundAddress,
      LnSendSwap() => swap.refundAddress,
      LnReceiveSwap() => null,
    };
    final String refundAddress;
    if (knownAddress != null) {
      refundAddress = knownAddress;
    } else {
      switch (await _newAddressFor(sendWalletId)) {
        case Ok(:final value):
          refundAddress = value;
          await updateSwapFields(swap.id, refundAddress: value);
        case Err(:final failure):
          return Err(failure);
      }
    }

    try {
      final (txid, _) = await _electrum.run(
        isLiquid: refundOnLiquid,
        environment: _environment,
        isTransient: _isServerFailure,
        operation: (connection) => _attemptRefund(
          swap,
          refundAddress: refundAddress,
          isLiquid: refundOnLiquid,
          connection: connection,
          scriptPathOnly: scriptPathOnly,
        ),
      );
      return Ok(txid);
    } catch (e) {
      if (e is SwapsFailure) rethrow;
      // A non-final rejection means the timelock has not passed — nothing of
      // ours can be on-chain, so the outspend recovery must not get the
      // chance to match an unrelated spend. It is expected while a swap
      // waits out its timeout, so it is not reported as an error.
      if (_isNonFinalError(e)) {
        swapsLog.fine('SWAPS: refund for ${swap.id} waits for its timelock');
        throw SwapsException(
          'refund for ${swap.id} is not yet final (timelock); retry later',
        );
      }
      if (_errorMessage(e).toLowerCase().contains('missingorspent')) {
        swapsLog.warning(
          'SWAPS: refund for ${swap.id} found the lockup already spent',
        );
      } else {
        swapsLog.severe(
          'SWAPS: refund failed for ${swap.id}: ${_errorMessage(e)}',
          error: e,
        );
      }
      // The script-path-only (zero-Boltz) retry must not fall back to the
      // outspend recovery, which queries the Boltz API. Surface the failure.
      if (scriptPathOnly) {
        await swapsLog.flush();
        throw SwapsException(
          'refund failed for ${swap.id}: ${_errorMessage(e)}',
        );
      }
      final recovered = await _recoverFromVerifiedOutspend(
        swap,
        isClaim: false,
      );
      await swapsLog.flush();
      if (recovered != null) return Ok(recovered);
      throw SwapsException('refund failed for ${swap.id}: ${_errorMessage(e)}');
    }
  }

  Future<void> coopSign(Swap swap) async {
    if (swap is! LnSendSwap) return;
    try {
      final preimage =
          swap.preimage ?? await getSendSwapPreimage(swapId: swap.id);
      // The coop close MuSig-signs whatever transaction hash the server
      // hands us (a key-path sweep of OUR lockup), so the invoice must be
      // proven paid (preimage hashes to its payment hash) before we sign —
      // and before the preimage is stored as that proof. Refusing is
      // invisible to the user: an honest Boltz claims via the script path.
      final proven =
          preimage != null &&
          preimageMatchesInvoice(preimage: preimage, invoice: swap.invoice);
      if (proven && swap.preimage == null) {
        await updateSwapFields(swap.id, preimage: preimage);
      }
      if (!proven) {
        throw SwapsException(
          'not coop-signing ${swap.id}: server preimage '
          '${preimage == null ? 'missing' : 'does not hash to the invoice '
                    'payment hash'} — swap completes via transaction.claimed',
        );
      }
      if (swap.type == SwapType.bitcoinToLightning) {
        await coopSignBitcoinToLightningSwap(swapId: swap.id);
      } else {
        await coopSignLiquidToLightningSwap(swapId: swap.id);
      }
      unsubscribeFromSwaps([swap.id]);
      swapsLog.fine('SWAPS: coop close succeeded for ${swap.id}');
    } catch (e) {
      // Non-fatal: the swap still settles via the script path and the
      // transaction.claimed event.
      swapsLog.warning(
        'SWAPS: coop close skipped/failed for ${swap.id}: ${_errorMessage(e)}',
      );
      rethrow;
    }
  }

  Future<(String, int)> _attemptRefund(
    Swap swap, {
    required String refundAddress,
    required bool isLiquid,
    required ElectrumConnection connection,
    bool scriptPathOnly = false,
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
            electrum: connection,
          );
        case SwapType.bitcoinToLightning:
          return refundBitcoinToLightningSwap(
            swapId: swap.id,
            bitcoinAddress: refundAddress,
            absoluteFees: fees,
            cooperate: cooperate,
            electrum: connection,
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
        electrum: connection,
      ),
      isLiquid: isLiquid,
      amountSat: _amountSatOrNull(swap),
    );

    String txid;
    int fees;
    if (scriptPathOnly) {
      // Zero-Boltz retry: go straight to the script path. Cooperative sizing
      // and signing both round-trip the Boltz API, so they are skipped.
      fees = await feesFor(cooperative: false);
      swapsLog.fine(
        'SWAPS: ${swap.id} script-path-only refund fees=$fees '
        'server=${connection.url}',
      );
      txid = await broadcast(cooperate: false, fees: fees);
    } else {
      try {
        fees = await feesFor(cooperative: true);
        swapsLog.fine(
          'SWAPS: ${swap.id} cooperative refund fees=$fees '
          'server=${connection.url}',
        );
        txid = await broadcast(cooperate: true, fees: fees);
      } catch (e) {
        if (e is SwapsFailure) rethrow;
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

  Future<Result<String, SwapsFailure>> _resolveClaimAddress(Swap swap) async {
    final String walletId;
    switch (swap) {
      case LnReceiveSwap():
        final existing = swap.receiveAddress;
        if (existing != null) return Ok(existing);
        walletId = swap.receiveWalletId;
      case ChainSwap():
        final existing = swap.receiveAddress;
        if (existing != null) {
          final uri = Uri.tryParse(existing);
          if (uri != null && uri.scheme.isNotEmpty && uri.path.isNotEmpty) {
            // bip21-style stored destination (bitcoin:/liquidnetwork:...).
            return Ok(uri.path);
          }
          return Ok(existing);
        }
        final receiveWalletId = swap.receiveWalletId;
        if (receiveWalletId == null) {
          throw SwapsException(
            'chain swap ${swap.id} has neither a receive wallet nor a '
            'receive address',
          );
        }
        walletId = receiveWalletId;
      case LnSendSwap():
        throw SwapsException('submarine swaps have no claim address');
    }
    final result = await _newAddressFor(walletId);
    if (result case Ok(:final value)) {
      await updateSwapFields(swap.id, receiveAddress: value);
    }
    return result;
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
        environment: _environment,
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
    ElectrumConnection? electrum,
  }) {
    switch (swap.type) {
      case SwapType.lightningToBitcoin:
        return claimLightningToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: absoluteFees,
          bitcoinAddress: claimAddress,
          cooperate: cooperate,
          electrum: electrum,
        );
      case SwapType.lightningToLiquid:
        return claimLightningToLiquidSwap(
          swapId: swap.id,
          absoluteFees: absoluteFees,
          liquidAddress: claimAddress,
          cooperate: cooperate,
          electrum: electrum,
        );
      case SwapType.bitcoinToLiquid:
        return claimBitcoinToLiquidSwap(
          swapId: swap.id,
          absoluteFees: absoluteFees,
          liquidClaimAddress: claimAddress,
          cooperate: cooperate,
          electrum: electrum,
        );
      case SwapType.liquidToBitcoin:
        return claimLiquidToBitcoinSwap(
          swapId: swap.id,
          absoluteFees: absoluteFees,
          bitcoinClaimAddress: claimAddress,
          cooperate: cooperate,
          electrum: electrum,
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

      final isLiquid = switch (swap) {
        ChainSwap() =>
          isClaim
              ? swap.type == SwapType.bitcoinToLiquid
              : swap.type == SwapType.liquidToBitcoin,
        LnReceiveSwap() => swap.type == SwapType.lightningToLiquid,
        LnSendSwap() => swap.type == SwapType.liquidToLightning,
      };
      if (await _electrum.usesCustomServers(
        isLiquid: isLiquid,
        environment: _environment,
      )) {
        swapsLog.fine(
          'SWAPS: ${swap.id} outspend lookup skipped — custom electrum',
        );
        return null;
      }
      final network = Network.fromEnvironment(
        environment: _environment,
        isLiquid: isLiquid,
      );
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
        // A txid already recorded on ANOTHER swap row can never be this
        // swap's settlement — rejects a backend replaying a historical
        // claim/refund of ours as evidence for a different swap.
        final recordedOn = await _swapRecordingTxid(txid, except: swap.id);
        if (recordedOn != null) {
          swapsLog.warning(
            'SWAPS: ${swap.id} spender $txid already belongs to swap '
            '$recordedOn — ignoring',
          );
          continue;
        }
        // Refund side: OUR lockup txid is locally known (we broadcast it),
        // so the candidate must actually spend it. The claim side cannot be
        // bound this way — the server's lockup txid only comes from the
        // server itself.
        final lockupTxid = switch (swap) {
          LnSendSwap(:final sendTxid) => sendTxid,
          ChainSwap(:final sendTxid) => sendTxid,
          LnReceiveSwap() => null,
        };
        if (!isClaim &&
            lockupTxid != null &&
            tx.spendsTxIds.isNotEmpty &&
            !tx.spendsTxIds.contains(lockupTxid)) {
          swapsLog.warning(
            'SWAPS: ${swap.id} spender $txid does not spend our lockup '
            '$lockupTxid — ignoring',
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

  // Substring classification is a known tradeoff: bull_sdk surfaces remote
  // errors as free text, and electrum implementations word them differently.
  // Misrouting fails safe in both directions — an unmatched non-final error
  // skips outspend recovery and retries later; an unmatched server failure
  // just skips the extra server walk. Typed error codes from bull_sdk are
  // the eventual fix.
  bool _isLockupNotVisible(Object error) {
    final message = _errorMessage(error).toLowerCase();
    return message.contains('not yet visible to the chain client') ||
        message.contains('no bitcoin utxo detected') ||
        message.contains('bitcoin lockup not yet confirmed');
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
    // Readiness is checked before asking the key source: deriving reads the
    // wallet seed, which must only happen on the one first derivation, never
    // on every create/restore/rescue.
    final fingerprint = await defaultBitcoinFingerprint();
    if (fingerprint != null &&
        await swapMasterKeyReady(walletFingerprint: fingerprint)) {
      return;
    }
    final key = await _swapMasterKeySource(environment: _environment);
    if (key == null) {
      throw SwapsException(
        'no default bitcoin wallet seed available to derive the swap '
        'master key (watch-only or hardware-only wallet)',
      );
    }
    if (await swapMasterKeyReady(walletFingerprint: key.walletFingerprint)) {
      return;
    }
    await storeSwapMasterKey(key);
    swapsLog.fine(
      'SWAPS: swap master key stored for wallet ${key.walletFingerprint}',
    );
  }

  Future<List<RestoredSwap>> _restore() async {
    await _ensureMasterKey();
    return restoreSwaps(environment: _environment);
  }

  Future<Swap> _rescue(
    RestoredSwap restored, {
    required String walletId,
  }) async {
    if (restored.environment != _environment) {
      throw SwapsException('Restored swap belongs to another network');
    }
    final wallets = await _wallets(environment: _environment);
    final selected = wallets.where((w) => w.id == walletId).firstOrNull;
    if (selected == null || selected.isLiquid != restored.actsOnLiquid) {
      throw SwapsException(
        'rescue wallet is not on the '
        '${restored.actsOnLiquid ? 'Liquid' : 'Bitcoin'} side of this swap',
      );
    }
    await _ensureMasterKey();
    final btcElectrumUrl = await _electrumUrl(isLiquid: false);
    final lbtcElectrumUrl = await _electrumUrl(isLiquid: true);

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

  /// Re-verifies recorded settlements against the wallet that should have
  /// been paid and reopens the ones that never were: false chain completions
  /// as claimable (Boltz reported claiming our lockup, so it holds the
  /// preimage and Boltz's own lockup is ours to claim before its timeout),
  /// false reverse completions as claimable (MRH direct payments excepted),
  /// false refunds as refundable (broadcast accepted but the tx vanished —
  /// withheld or evicted).
  /// Cache-first: the wallet is only force-synced when the recorded txid is
  /// MISSING from the cached view, so the common all-good launch does no
  /// network work per swap.
  Future<void> _verifyCompletions() async {
    try {
      final swaps = await getAllSwaps();
      for (final swap in swaps) {
        // (txid that proves the settlement, wallet it must have paid,
        // status to reopen as, whether the failed proof was a claim)
        final (
          String? proofTxid,
          String? walletId,
          SwapStatus reopenAs,
          bool isClaim,
        ) = switch ((swap, swap.status)) {
          (
            ChainSwap(
              :final refundTxid,
              :final sendTxid,
              :final receiveTxid,
              :final receiveWalletId,
            ),
            SwapStatus.completed,
          )
              when refundTxid == null && sendTxid != null =>
            (receiveTxid, receiveWalletId, SwapStatus.claimable, true),
          (
            LnReceiveSwap(
              :final wasDirectPayment,
              :final receiveTxid,
              :final receiveWalletId,
            ),
            SwapStatus.completed,
          )
              when !wasDirectPayment =>
            (receiveTxid, receiveWalletId, SwapStatus.claimable, true),
          (
            ChainSwap(:final refundTxid, :final sendTxid, :final sendWalletId),
            SwapStatus.refunded,
          )
              when sendTxid != null =>
            (refundTxid, sendWalletId, SwapStatus.refundable, false),
          (
            LnSendSwap(:final refundTxid, :final sendTxid, :final sendWalletId),
            SwapStatus.refunded,
          )
              when sendTxid != null =>
            (refundTxid, sendWalletId, SwapStatus.refundable, false),
          _ => (null, null, SwapStatus.completed, false),
        };
        if (reopenAs == SwapStatus.completed) continue;
        // A settlement recorded moments ago may not be visible to electrum
        // yet — never judge it on this launch; the next one will.
        final completedAt = swap.completionTime;
        if (completedAt != null &&
            DateTime.now().difference(completedAt) <
                const Duration(minutes: 10)) {
          continue;
        }
        if (proofTxid == null) {
          if (swap is! ChainSwap || swap.status != SwapStatus.completed) {
            continue; // reverse: the watcher re-claims
          }
          swapsLog.warning(
            'SWAPS: ${swap.id} completed with funds locked and no txid '
            'recorded — reopening as ${reopenAs.name}',
          );
          await updateSwapFields(swap.id, status: reopenAs);
          continue;
        }
        if (walletId == null) continue;
        try {
          var txs = await _walletTxs(walletId);
          if (txs == null || txs.any((tx) => tx.txId == proofTxid)) continue;
          // Missing from cache: force one fresh sync before judging.
          // Retraction requires a successful refresh.
          txs = await _walletTxs(walletId, sync: true);
          if (txs == null || txs.isEmpty) continue;
          if (txs.any((tx) => tx.txId == proofTxid)) continue;
          swapsLog.warning(
            'SWAPS: ${swap.id} ${swap.status.name} but recorded '
            '${isClaim ? 'claim' : 'refund'} $proofTxid is not in wallet '
            '$walletId — retracting and reopening as ${reopenAs.name}',
          );
          // claimFee 0 = "no trustworthy stored fee": a vanished claim means
          // the pinned creation-time fee failed (possibly evicted), so the
          // re-claim estimates live instead of repeating it.
          await updateSwapFields(
            swap.id,
            status: reopenAs,
            clearReceiveTxid: isClaim,
            clearRefundTxid: !isClaim,
            claimFee: isClaim ? 0 : null,
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

/// A rescued swap written over [existing]: what the row already recorded
/// (txids, addresses, a pending lockup, a settled status) is kept; the rescue
/// only fills the rest.
@visibleForTesting
SwapModel mergeRescuedSwap(SwapModel existing, SwapModel rescued) => switch ((
  existing,
  rescued,
)) {
  (final ChainSwapModel e, final ChainSwapModel r) => r.copyWith(
    status: e.receiveTxid != null || e.refundTxid != null ? e.status : r.status,
    sendTxid: e.sendTxid ?? r.sendTxid,
    receiveTxid: e.receiveTxid,
    refundTxid: e.refundTxid,
    receiveAddress: e.receiveAddress ?? r.receiveAddress,
    refundAddress: e.refundAddress ?? r.refundAddress,
    pendingLockupTx: e.pendingLockupTx,
    pendingLockupTxid: e.pendingLockupTxid,
    completionTime: e.completionTime,
  ),
  (final LnSendSwapModel e, final LnSendSwapModel r) => r.copyWith(
    status: e.refundTxid != null ? e.status : r.status,
    sendTxid: e.sendTxid ?? r.sendTxid,
    refundTxid: e.refundTxid,
    refundAddress: e.refundAddress ?? r.refundAddress,
    preimage: e.preimage ?? r.preimage,
    pendingLockupTx: e.pendingLockupTx,
    pendingLockupTxid: e.pendingLockupTxid,
    completionTime: e.completionTime,
  ),
  (final LnReceiveSwapModel e, final LnReceiveSwapModel r) => r.copyWith(
    status: e.receiveTxid != null ? e.status : r.status,
    receiveTxid: e.receiveTxid,
    receiveAddress: e.receiveAddress ?? r.receiveAddress,
    wasDirectPayment: e.wasDirectPayment,
    completionTime: e.completionTime,
  ),
  _ => rescued,
};
