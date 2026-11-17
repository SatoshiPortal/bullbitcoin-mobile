import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';

import '../../ark.dart';
import 'ark_native_session.dart';

/// Sole bark import/opener. Never attach the native logger: foreign diagnostics
/// can carry Lightning preimages. Child words exist only during this open.
final class BarkNativeOpener implements ArkNativeOpener {
  final BarkOpenBoundary boundary;
  const BarkNativeOpener({this.boundary = const FfiBarkOpenBoundary()});
  @override
  bool datadirExists(String datadir) =>
      Directory(datadir).existsSync() &&
      Directory(datadir).listSync().isNotEmpty;
  @override
  Future<ArkNativeSession> open({
    required ArkAccountConfig config,
    required String datadir,
    required String mnemonic,
    required Uri chainSource,
    required bool create,
    required String? expectedFingerprint,
    required bool nativePreviouslyAdmitted,
    required void Function() onNativeAdmission,
    required ArkStageRunner stages,
    required void Function() onOnchainOpened,
    required void Function(ArkRecoveryStatus recovery, String fingerprint)
    onOpened,
  }) async {
    final network = switch (config.id.network) {
      BitcoinNetwork.mainnet => bark.Network.bitcoin,
      BitcoinNetwork.testnet => bark.Network.testnet,
      BitcoinNetwork.signet => bark.Network.signet,
      BitcoinNetwork.regtest => bark.Network.regtest,
    };
    final existing = await stages.run(
      'datadir-info',
      () async => boundary.inspect(datadir),
    );
    final derived = deriveBarkChildFingerprint(mnemonic);
    if ((expectedFingerprint != null && expectedFingerprint != derived) ||
        (existing != null &&
            (existing.network != network || existing.fingerprint != derived))) {
      throw const ArkBoundaryException(
        ArkValidationFailure(ArkFailureReason.identityMismatch),
      );
    }
    if (existing == null &&
        (!create ||
            nativePreviouslyAdmitted ||
            expectedFingerprint != null ||
            boundary.hasData(datadir))) {
      throw const ArkBoundaryException(ArkRecoveryRequiredFailure());
    }
    final nativeConfig = bark.Config(
      serverAddress: config.arkUrl.toString(),
      esploraAddress: chainSource.toString(),
      vtxoRefreshExpiryThreshold: config.renewalThresholdBlocks,
    );
    final onchain = await stages.run('open-onchain', () {
      onNativeAdmission();
      return boundary.openOnchain(
        network: network,
        mnemonic: mnemonic,
        config: nativeConfig,
        datadir: datadir,
      );
    });
    try {
      onOnchainOpened();
      final wallet = await stages.run('open-ark', () async {
        final wallet = await boundary.openWallet(
          network: network,
          mnemonicOrSeed: mnemonic,
          config: nativeConfig,
          args: bark.WalletOpenArgs(
            runDaemon: false,
            datadir: datadir,
            onchain: onchain,
            createIfNotExists: create && existing == null,
          ),
        );
        try {
          // Persist the admitted open's outcome before budget can revoke any
          // subsequent stage. NotRun cannot erase a prior recovery result.
          onOpened(
            mapBarkRecovery(wallet.recoveryStatus()),
            wallet.fingerprint(),
          );
          return wallet;
        } catch (_) {
          wallet.dispose();
          rethrow;
        }
      });
      return BarkNativeSession(wallet, onchain, stages, config);
    } catch (_) {
      onchain.dispose();
      rethrow;
    }
  }
}

final class BarkNativeSession implements ArkNativeSession {
  final bark.Wallet _wallet;
  final bark.OnchainWallet _onchain;
  final ArkStageRunner _stages;
  final ArkAccountConfig _config;
  BarkNativeSession(this._wallet, this._onchain, this._stages, this._config);

  Future<T> _run<T>(String name, Future<T> Function() action) =>
      _stages.run(name, action);
  @override
  Future<void> synchronizeStage(String name) async {
    switch (name) {
      case 'ark':
        await _run(name, _wallet.sync_);
      case 'lightning':
        await _run(
          name,
          () => _wallet.tryClaimAllLightningReceives(wait: false),
        );
      case 'rounds':
        await _run(name, _wallet.progressPendingRounds);
      case 'boards':
        await _run(name, _wallet.syncPendingBoards);
      case 'server':
        await _run(name, _wallet.refreshServer);
      case 'onchain':
        await _run(name, _onchain.sync_);
      case 'initial-scan':
        await _run(name, () => _onchain.initialScan(birthdayHeight: null));
      case 'exits-observe':
        await _run(name, _wallet.syncExits);
      default:
        throw ArgumentError('Unknown native stage');
    }
  }

  @override
  Future<ArkSnapshot> observe({
    required ArkAccountId account,
    required int revision,
    required DateTime now,
    required Uri chainSource,
    required List<ArkOperation> operations,
    required ArkRecoveryStatus previousRecovery,
  }) async {
    final balance = await _run('balance', _wallet.balance);
    final reserve = await _run('reserve', _onchain.balance);
    final tip = await _run('tip', _onchain.tipHeight);
    final pendingIds = (await _run(
      'round-inputs',
      _wallet.pendingRoundInputVtxos,
    )).map((v) => v.id).toSet();
    final nativeVtxos = await _run('vtxos', _wallet.allVtxos);
    final rounds = await _run('pending-rounds', _wallet.pendingRoundStates);
    final boards = await _run('pending-boards', _wallet.pendingBoards);
    final receives = await _run(
      'pending-receives',
      _wallet.pendingLightningReceives,
    );
    final sends = await _run('pending-sends', _wallet.pendingLightningSends);
    final exits = await _run('exit-states', _wallet.getExitVtxos);
    final history = await _run('history', _wallet.history);
    final info = await _run('server-info', _wallet.arkInfo);
    final vtxos = nativeVtxos
        .map(
          (v) => ArkVtxo(
            id: v.id,
            amount: Sats.fromInt(v.amountSats),
            expiryHeight: v.expiryHeight,
            state: switch (v.state) {
              bark.SpendableVtxoState() => ArkVtxoState.spendable,
              bark.LockedVtxoState() => ArkVtxoState.locked,
              bark.SpentVtxoState() => ArkVtxoState.spent,
              bark.ExitedVtxoState() => ArkVtxoState.exited,
              _ => ArkVtxoState.unknown,
            },
            anchor: v.id,
            pendingRound: pendingIds.contains(v.id),
          ),
        )
        .toList();
    final recoveryStatus = await _run(
      'recovery-status',
      () async => _wallet.recoveryStatus(),
    );
    final currentRecovery = switch (recoveryStatus) {
      bark.CompletedRecoveryStatus(:final report) =>
        report.isComplete
            ? ArkRecoveryStatus.complete
            : ArkRecoveryStatus.incomplete,
      bark.FailedRecoveryStatus() => ArkRecoveryStatus.failed,
      bark.NotRunRecoveryStatus() => previousRecovery,
      _ => ArkRecoveryStatus.unknown,
    };
    final pending =
        balance.pendingInRoundSats +
        balance.pendingExitSats +
        balance.pendingLightningSendSats +
        balance.claimableLightningReceiveSats +
        balance.pendingBoardSats +
        balance.pendingArkoorSendSats +
        balance.pendingOffboardSats;
    final liveExits = exits
        .where(
          (v) =>
              v.state is! bark.ClaimedExitState &&
              v.state is! bark.VtxoSweptExitState &&
              v.state is! bark.VtxoAlreadySpentExitState &&
              v.state is! bark.CanceledExitState,
        )
        .toList();
    return ArkSnapshot(
      account: account,
      revision: revision,
      observedAt: now,
      tipHeight: tip,
      stale: currentRecovery != ArkRecoveryStatus.complete,
      spendable: Sats.fromInt(balance.spendableSats),
      pending: Sats.fromInt(pending),
      pendingBoardBalance: Sats.fromInt(balance.pendingBoardSats),
      confirmedReserve: Sats.fromInt(reserve.confirmedSats),
      vtxos: vtxos,
      vtxoCompleteness: currentRecovery == ArkRecoveryStatus.complete
          ? ArkSectionCompleteness.complete
          : ArkSectionCompleteness.incomplete,
      exitDetails: exits
          .map(
            (e) => ArkExit(
              id: e.vtxoId,
              amount: Sats.fromInt(e.amountSats),
              status: switch (e.state) {
                bark.ClaimableExitState() => ArkExitStatus.claimable,
                bark.ClaimInProgressExitState() => ArkExitStatus.submitted,
                bark.ClaimedExitState() => ArkExitStatus.claimed,
                bark.VtxoSweptExitState() ||
                bark.VtxoAlreadySpentExitState() => ArkExitStatus.failed,
                bark.CanceledExitState() => ArkExitStatus.none,
                _ => ArkExitStatus.pending,
              },
              claimableHeight: switch (e.state) {
                bark.AwaitingDeltaExitState(:final claimableHeight) =>
                  claimableHeight,
                bark.ClaimableExitState(:final claimableSince) =>
                  claimableSince.height,
                _ => null,
              },
              claimTxid: switch (e.state) {
                bark.ClaimInProgressExitState(:final claimTxid) => claimTxid,
                bark.ClaimedExitState(:final txid) => txid,
                _ => null,
              },
            ),
          )
          .toList(),
      pendingBoards: boards
          .map(
            (b) => ArkPendingBoard(
              vtxoId: b.vtxoId,
              fundingTxid: b.txid,
              amount: Sats.fromInt(b.amountSats),
              expiryHeight: switch (operations
                  .where((o) => o.nativeReference == b.txid)
                  .firstOrNull
                  ?.boardFunding) {
                final funding? => funding.expiryHeight,
                null => null,
              },
            ),
          )
          .toList(),
      operations: operations,
      pendingBoardCount: boards.length,
      pendingLightningCount: receives.length + sends.length,
      pendingRoundCount: rounds.length,
      usingFallback: chainSource != _config.primaryEsploraUrl,
      movements: history
          .map(
            (v) => ArkMovement(
              id: v.id.toString(),
              kind: switch (v.subsystemName) {
                'bark.board' => ArkMovementKind.board,
                'bark.round' => ArkMovementKind.renewal,
                'bark.exit' => ArkMovementKind.exit,
                'bark.arkoor' ||
                'bark.offboard' ||
                'bark.lightning_send' => ArkMovementKind.payment,
                'bark.lightning_receive' => ArkMovementKind.lightningReceive,
                _ => ArkMovementKind.unknown,
              },
              status: switch (v.status) {
                'successful' => ArkMovementStatus.successful,
                'pending' => ArkMovementStatus.pending,
                'failed' => ArkMovementStatus.failed,
                _ => ArkMovementStatus.unknown,
              },
              amount: Sats.fromInt(v.effectiveBalanceSats.abs()),
              fee: Sats.fromInt(v.offchainFeeSats),
              createdAt: DateTime.tryParse(v.createdAt),
              inputVtxoIds: List.unmodifiable(v.inputVtxoIds),
              outputVtxoIds: List.unmodifiable(v.outputVtxoIds),
            ),
          )
          .toList(),
      serverInfo: info == null
          ? null
          : ArkServerInfo(
              publicKey: info.serverPubkey,
              roundIntervalSeconds: info.roundIntervalSecs,
              vtxoLifetimeBlocks: info.vtxoLifetime,
              minimumBoard: Sats.fromInt(info.minBoardAmountSats),
              maximumVtxo: switch (info.maxVtxoAmountSats) {
                final amount? => Sats.fromInt(amount),
                null => null,
              },
              boardConfirmations: info.requiredBoardConfirmations,
            ),
      renewal: pendingIds.isNotEmpty
          ? ArkRenewalStatus.delegated
          : vtxos.any(
              (v) => v.renewalDueAt(tip, _config.renewalThresholdBlocks),
            )
          ? ArkRenewalStatus.due
          : ArkRenewalStatus.current,
      exits: liveExits.any((e) => e.isClaimable)
          ? ArkExitStatus.claimable
          : liveExits.isNotEmpty
          ? ArkExitStatus.pending
          : ArkExitStatus.none,
      recovery: currentRecovery,
      obligations:
          pending > 0 ||
              reserve.totalSats > 0 ||
              liveExits.isNotEmpty ||
              boards.isNotEmpty ||
              rounds.isNotEmpty ||
              receives.isNotEmpty ||
              sends.isNotEmpty ||
              vtxos.any(
                (v) =>
                    v.state != ArkVtxoState.spent &&
                    v.state != ArkVtxoState.exited,
              )
          ? ArkObligationStatus.present
          : ArkObligationStatus.none,
    );
  }

  @override
  Future<ArkQuote> estimate({
    required ArkSnapshot snapshot,
    required ArkQuoteRequest request,
    required String id,
    required Uri chainSource,
    required int configGeneration,
    required DateTime now,
  }) async {
    final tip = snapshot.tipHeight;
    if (tip == null) {
      throw const ArkBoundaryException(
        ArkUnavailableFailure(ArkFailureReason.unavailable),
      );
    }
    bark.FeeEstimate? estimate;
    ArkOperationKind kind;
    List<String> selected = [];
    List<String> reserveCoins = [];
    String? destination;
    ArkDestinationKind? destinationKind;
    Sats? maximumClaim;
    Sats? exposure;
    FeeRate? rate;
    int? exitFee;
    int? exitAmount;
    switch (request) {
      case ArkPaymentQuoteRequest(:final amount, :final destination):
        kind = ArkOperationKind.payment;
        final parsed = await _run(
          'parse-payment',
          () => _wallet.parsePaymentRequest(payment: destination.value),
        );
        final options = parsed.options.where(
          (o) =>
              o.errors.isEmpty &&
              switch ((destination.kind, o.method)) {
                (ArkDestinationKind.ark, bark.ArkPaymentMethod()) => true,
                (ArkDestinationKind.bolt11, bark.InvoicePaymentMethod()) =>
                  true,
                (ArkDestinationKind.bitcoin, bark.BitcoinPaymentMethod()) =>
                  true,
                _ => false,
              },
        );
        if (options.isEmpty ||
            (parsed.amountSats != null &&
                parsed.amountSats != amount.value.toInt())) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.validation),
          );
        }
        estimate = await _run(
          'estimate-payment',
          () => _wallet.estimatePaymentFee(
            method: options.first.method,
            amountSats: amount.value.toInt(),
          ),
        );
        destinationKind = destination.kind;
      case ArkRenewalQuoteRequest(:final ids):
        kind = ArkOperationKind.renewal;
        selected = ids;
        estimate = await _run(
          'estimate-renewal',
          () => _wallet.estimateRefreshFee(vtxoIds: ids),
        );
      case ArkBoardQuoteRequest(:final amount):
        kind = ArkOperationKind.board;
        final info = snapshot.serverInfo;
        final minimum = info?.minimumBoard;
        if (info == null) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.validation),
          );
        }
        if (minimum != null && amount.compareTo(minimum) < 0) {
          throw ArkBoundaryException(
            ArkValidationFailure.belowMinimum(minimum),
          );
        }
        estimate = await _run(
          'estimate-board',
          () => _wallet.estimateBoardFee(amountSats: amount.value.toInt()),
        );
      case ArkEmergencyExitQuoteRequest(
        :final ids,
        :final destination,
        :final feeRate,
        :final maxClaimFee,
      ):
        kind = ArkOperationKind.emergencyExit;
        if (!ids.every(
          (id) => snapshot.vtxos.any(
            (v) =>
                v.id == id &&
                v.state == ArkVtxoState.spendable &&
                !v.pendingRound,
          ),
        )) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.invalidSelection),
          );
        }
        selected = ids;
        maximumClaim = maxClaimFee;
        rate = feeRate;
        final estimateExit = await _run(
          'estimate-exit',
          () => _wallet.estimateEmergencyExitFee(
            vtxoIds: ids,
            feeRateSatPerVb: _integerRate(feeRate),
            destination: destination,
            feeMargin: null,
          ),
        );
        exitFee = estimateExit.totalFeeSats;
        exitAmount = _sumSelected(snapshot, ids);
      case ArkExitProgressQuoteRequest(:final feeRate):
        kind = ArkOperationKind.exitProgress;
        rate = feeRate;
        final live = await _run('live-exits', _wallet.getExitVtxos);
        selected = live
            .where(
              (v) =>
                  v.state is! bark.ClaimedExitState &&
                  v.state is! bark.VtxoSweptExitState &&
                  v.state is! bark.VtxoAlreadySpentExitState &&
                  v.state is! bark.CanceledExitState,
            )
            .map((v) => v.vtxoId)
            .toList();
        if (selected.isEmpty) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.validation),
          );
        }
        final estimated = await _run(
          'estimate-progress',
          () => _wallet.estimateEmergencyExitFee(
            vtxoIds: selected,
            feeRateSatPerVb: _integerRate(feeRate),
            destination: null,
            feeMargin: null,
          ),
        );
        exitFee = estimated.exitBroadcastFeeSats;
        exitAmount = live
            .where((v) => selected.contains(v.vtxoId))
            .fold<int>(0, (sum, v) => sum + v.amountSats);
      case ArkClaimQuoteRequest(:final ids, :final destination, :final maxFee):
        kind = ArkOperationKind.claim;
        selected = ids;
        maximumClaim = maxFee;
        final claimable = await _run('claimable', _wallet.listClaimableExits);
        if (!ids.every((id) => claimable.any((v) => v.vtxoId == id))) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.validation),
          );
        }
        final estimated = await _run(
          'estimate-claim',
          () => _wallet.estimateEmergencyExitFee(
            vtxoIds: ids,
            feeRateSatPerVb: null,
            destination: destination,
            feeMargin: null,
          ),
        );
        exitFee = estimated.claimFeeSats;
        exitAmount = claimable
            .where((v) => ids.contains(v.vtxoId))
            .fold<int>(0, (sum, v) => sum + v.amountSats);
        if (BigInt.from(exitFee) > maxFee.value) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.validation),
          );
        }
    }
    destination = switch (request) {
      ArkPaymentQuoteRequest(:final destination) => destination.value,
      ArkEmergencyExitQuoteRequest(:final destination) => destination,
      ArkClaimQuoteRequest(:final destination) => destination,
      _ => null,
    };
    if (kind == ArkOperationKind.exitProgress ||
        kind == ArkOperationKind.emergencyExit) {
      await _run('exit-reserve-sync', _onchain.sync_);
      final reserve = await _run('exit-reserve', _onchain.balance);
      final coins = await _run('exit-reserve-coins', _onchain.utxos);
      reserveCoins =
          coins
              .whereType<bark.LocalOnchainUtxo>()
              .where((v) => v.confirmationHeight != null)
              .map(
                (v) => '${v.outpoint.txid}:${v.outpoint.vout}:${v.amountSats}',
              )
              .toList()
            ..sort();
      exposure = Sats.fromInt(reserve.confirmedSats);
      if (BigInt.from(exitFee ?? 0) > exposure.value) {
        throw const ArkBoundaryException(ArkInsufficientFundsFailure());
      }
    }
    if (estimate case final value?) {
      if (value.netAmountSats <= 0 || value.feeSats < 0) {
        throw const ArkBoundaryException(
          ArkValidationFailure(ArkFailureReason.validation),
        );
      }
      if (kind != ArkOperationKind.board) {
        selected = value.vtxosSpent;
        if (selected.isEmpty ||
            selected.toSet().length != selected.length ||
            !selected.every(
              (id) =>
                  snapshot.vtxos.any((v) => v.id == id && v.eligibleAt(tip)),
            )) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.invalidSelection),
          );
        }
        if (request case ArkRenewalQuoteRequest(:final ids)) {
          if (selected.toSet().difference(ids.toSet()).isNotEmpty ||
              ids.toSet().difference(selected.toSet()).isNotEmpty) {
            throw const ArkBoundaryException(
              ArkValidationFailure(ArkFailureReason.invalidSelection),
            );
          }
        }
        final available = snapshot.spendable;
        if (available == null ||
            BigInt.from(value.grossAmountSats) > available.value) {
          throw const ArkBoundaryException(ArkInsufficientFundsFailure());
        }
      }
    }
    final amount = estimate?.grossAmountSats ?? exitAmount;
    final fee = estimate?.feeSats ?? exitFee;
    final net = estimate?.netAmountSats ?? ((amount ?? 0) - (fee ?? 0));
    if (amount == null || fee == null || net < 0) {
      throw const ArkBoundaryException(
        ArkValidationFailure(ArkFailureReason.validation),
      );
    }
    // bark0.8.1 VTXO_DUST = P2TR_DUST = 330 sats. Bitcoin destinations have
    // script-specific thresholds, validated by the native payment estimator.
    if ((kind == ArkOperationKind.board ||
            kind == ArkOperationKind.renewal ||
            (kind == ArkOperationKind.payment &&
                destinationKind == ArkDestinationKind.ark)) &&
        net < 330) {
      throw const ArkBoundaryException(
        ArkValidationFailure(ArkFailureReason.dust),
      );
    }
    return ArkQuote(
      id: id,
      account: snapshot.account,
      generation: snapshot.revision,
      chainSource: chainSource,
      configGeneration: configGeneration,
      kind: kind,
      amount: Sats.fromInt(amount),
      fee: Sats.fromInt(fee),
      net: Sats.fromInt(net),
      selectedIds: selected,
      reserveOutpoints: reserveCoins,
      destination: destination,
      destinationKind: destinationKind,
      observedTip: tip,
      validUntil: now.add(const Duration(minutes: 2)),
      feeRate: rate,
      confirmedReserveExposure: exposure,
      maxClaimFee: maximumClaim,
    );
  }

  static int _sumSelected(ArkSnapshot snapshot, List<String> ids) {
    if (!ids.every((id) => snapshot.vtxos.any((v) => v.id == id))) {
      throw const ArkBoundaryException(
        ArkValidationFailure(ArkFailureReason.invalidSelection),
      );
    }
    return snapshot.vtxos
        .where((v) => ids.contains(v.id))
        .fold(0, (sum, v) => sum + v.amount.value.toInt());
  }

  static int _integerRate(FeeRate rate) {
    if (rate.satsPerVbyte != rate.satsPerVbyte.roundToDouble()) {
      throw const ArkBoundaryException(
        ArkValidationFailure(ArkFailureReason.validation),
      );
    }
    return rate.satsPerVbyte.toInt();
  }

  @override
  Future<ArkOperation> execute(ArkQuote quote, String operationId) async {
    String? reference;
    var status = ArkOperationStatus.pending;
    switch (quote.kind) {
      case ArkOperationKind.payment:
        final destination = quote.destination;
        final destinationKind = quote.destinationKind;
        if (destination == null || destinationKind == null) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.validation),
          );
        }
        // Payment API uses destination amount, not gross including fee.
        final amount = quote.net.value.toInt();
        switch (destinationKind) {
          case ArkDestinationKind.ark:
            reference = (await _run(
              'send-ark',
              () => _wallet.sendArkoorPayment(
                arkAddress: destination,
                amountSats: amount,
              ),
            )).toString();
          case ArkDestinationKind.bolt11:
            final result = await _run(
              'send-lightning',
              () => _wallet.payLightningInvoice(
                invoice: destination,
                amountSats: amount,
                wait: false,
                retryForSecs: 0,
              ),
            );
            switch (result) {
              case bark.PaidLightningSendStatus(:final paymentHash):
                reference = paymentHash;
                status = ArkOperationStatus.succeeded;
              case bark.InProgressLightningSendStatus(:final send):
                reference = send.paymentHash;
                if (send.hasFailedRevocation) {
                  status = ArkOperationStatus.outcomeUnknown;
                }
              default:
                status = ArkOperationStatus.outcomeUnknown;
            }
          case ArkDestinationKind.bitcoin:
            reference = (await _run(
              'send-onchain',
              () =>
                  _wallet.sendOnchain(address: destination, amountSats: amount),
            )).movementId.toString();
        }
      case ArkOperationKind.renewal:
        final round = await _run(
          'renew',
          () => _wallet.refreshVtxosDelegated(vtxoIds: quote.selectedIds),
        );
        reference = round?.id.toString();
        if (round == null ||
            round.state == bark.RoundFlowKind.failed ||
            round.state == bark.RoundFlowKind.canceled) {
          status = ArkOperationStatus.outcomeUnknown;
        }
      case ArkOperationKind.emergencyExit:
        await _run(
          'start-exit',
          () => _wallet.startExitForVtxos(vtxoIds: quote.selectedIds),
        );
        final exits = await _run('verify-start-exit', _wallet.getExitVtxos);
        if (!quote.selectedIds.every(
          (id) => exits.any((v) => v.vtxoId == id),
        )) {
          status = ArkOperationStatus.outcomeUnknown;
        }
      case ArkOperationKind.exitProgress:
        final rate = quote.feeRate;
        if (rate == null) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.validation),
          );
        }
        final results = await _run(
          'progress-exits',
          () => _wallet.progressExits(feeRateSatPerVb: _integerRate(rate)),
        );
        if (results.any((v) => v.error != null)) {
          status = ArkOperationStatus.outcomeUnknown;
        }
      case ArkOperationKind.board:
      case ArkOperationKind.claim:
        throw const ArkBoundaryException(
          ArkValidationFailure(ArkFailureReason.validation),
        );
    }
    return ArkOperation(
      id: operationId,
      kind: quote.kind,
      status: status,
      chainSource: quote.chainSource,
      configGeneration: quote.configGeneration,
      nativeReference: reference,
      actualIds: quote.selectedIds,
    );
  }

  @override
  Future<List<String>> renewalCandidates() async => (await _run(
    'renewal-candidates',
    _wallet.getVtxosToRefresh,
  )).map((v) => v.id).toList();
  @override
  Future<String> reserveAddress() =>
      _run('reserve-address', _onchain.newAddress);
  @override
  Future<ArkBoardFundingDetails> boardFunding() async {
    final tuple = await _run('board-funding', _wallet.boardFundingAddress);
    return ArkBoardFundingDetails(
      address: tuple.address,
      keypairIndex: tuple.keypairIndex,
      expiryHeight: tuple.expiryHeight,
    );
  }

  @override
  Future<String> registerBoard(ArkRegisterBoard submission) async =>
      (await _run(
        'register-board',
        () => _wallet.boardPsbt(
          psbtBase64: submission.unfinalisedPsbt,
          keypairIndex: submission.keypairIndex,
          expiryHeight: submission.expiryHeight,
        ),
      )).txid;
  @override
  Future<ArkClaimTransaction> prepareClaim(ArkQuote quote) async {
    final destination = quote.destination;
    if (destination == null) {
      throw const ArkBoundaryException(
        ArkValidationFailure(ArkFailureReason.validation),
      );
    }
    final exits = await _run(
      'claim-input-evidence',
      _wallet.listClaimableExits,
    );
    final claim = await _run(
      'drain-exits',
      () => _wallet.drainExits(
        vtxoIds: quote.selectedIds,
        drainAll: false,
        address: destination,
        feeRateSatPerVb: null,
      ),
    );
    final raw = await _run(
      'extract-claim',
      () async => bark.extractTxFromPsbt(psbtBase64: claim.psbtBase64),
    );
    return ArkClaimTransaction(
      rawTransaction: raw,
      signedPsbt: claim.psbtBase64,
      actualIds: claim.vtxoIds,
      skippedIds: claim.skippedVtxoIds,
      inputAmounts: {for (final v in exits) v.vtxoId: v.amountSats.toString()},
      fee: claim.feeSats.toString(),
    );
  }

  @override
  Future<String> broadcast(String rawTransaction) =>
      _run('broadcast-claim', () => _wallet.broadcastTx(txHex: rawTransaction));
  @override
  Future<ArkReceiveDestination> receive(ArkReceiveRequest request) async {
    switch (request) {
      case ArkAddressReceiveRequest(:final amount, :final message):
        if (amount != null || (message != null && message.isNotEmpty)) {
          // Raw Ark addresses do not carry these optional payload fields.
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.unsupportedMethod),
          );
        }
        return ArkReceiveDestination(
          kind: ArkDestinationKind.ark,
          value: await _run('receive-ark', _wallet.newAddress),
        );
      case ArkBolt11ReceiveRequest(
        :final amount,
        :final description,
        :final expirySeconds,
      ):
        final fee = await _run(
          'receive-fee',
          () => _wallet.estimateLightningReceiveFee(
            amountSats: amount.value.toInt(),
          ),
        );
        if (fee.netAmountSats < 330) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.dust),
          );
        }
        final invoice = await _run(
          'receive-bolt11',
          () => _wallet.bolt11Invoice(
            amountSats: amount.value.toInt(),
            description: description,
            token: null,
            expirySecs: expirySeconds,
          ),
        );
        final decoded = await _run(
          'decode-invoice',
          () async => bark.decodeBolt11Invoice(invoice: invoice.invoice),
        );
        return ArkReceiveDestination(
          kind: ArkDestinationKind.bolt11,
          value: invoice.invoice,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            decoded.expiresAt * 1000,
            isUtc: true,
          ),
          net: Sats.fromInt(fee.netAmountSats),
          fee: Sats.fromInt(fee.feeSats),
        );
    }
  }

  Outpoint? _boardChainAnchor(String encoded) {
    if (encoded.length > 1024 * 1024) return null;
    try {
      final metadata = jsonDecode(encoded);
      if (metadata is! Map<String, dynamic> || metadata.length != 2) {
        return null;
      }
      final anchor = metadata['chain_anchor'],
          fee = metadata['onchain_fee_sat'];
      if (anchor is! String || fee is! int || fee < 0) return null;
      final parts = anchor.split(':');
      if (parts.length != 2 ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(parts[0]) ||
          !RegExp(r'^(0|[1-9][0-9]{0,9})$').hasMatch(parts[1])) {
        return null;
      }
      final vout = int.tryParse(parts[1]);
      if (vout == null || vout > 0xffffffff) return null;
      return (txId: parts[0], vout: vout);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<ArkOperation?> reconcile(ArkOperation operation) async {
    ArkOperationStatus? status;
    final reference = operation.nativeReference;
    if (operation.kind == ArkOperationKind.payment && reference != null) {
      if (int.tryParse(reference) != null) {
        final history = await _run('reconcile-movement', _wallet.history);
        for (final movement in history.where(
          (v) => v.id.toString() == reference,
        )) {
          status = switch (movement.status) {
            'successful' => ArkOperationStatus.succeeded,
            // Native delivery failure can follow consumed inputs.
            'failed' => ArkOperationStatus.outcomeUnknown,
            _ => ArkOperationStatus.pending,
          };
        }
      } else {
        final result = await _run(
          'reconcile-lightning',
          () => _wallet.lightningSendState(paymentHash: reference),
        );
        status = switch (result) {
          bark.PaidLightningSendStatus() => ArkOperationStatus.succeeded,
          bark.InProgressLightningSendStatus(:final send) =>
            send.hasFailedRevocation
                ? ArkOperationStatus.outcomeUnknown
                : ArkOperationStatus.pending,
          _ => ArkOperationStatus.outcomeUnknown,
        };
      }
    }
    if (operation.kind == ArkOperationKind.board && reference != null) {
      final vtxos = await _run('reconcile-board', _wallet.allVtxos);
      final history = await _run('reconcile-board-history', _wallet.history);
      final matched = <bark.Movement>[];
      for (final movement in history.where(
        (m) => m.subsystemName == 'bark.board' && m.subsystemKind == 'board',
      )) {
        final anchor = _boardChainAnchor(movement.metadataJson);
        if (anchor == null) return null; // Unsupported metadata is not proof.
        if (anchor.txId == reference) matched.add(movement);
      }
      if (matched.length == 1) {
        final movement = matched.single;
        if (movement.status == 'successful' &&
            movement.outputVtxoIds.length == 1 &&
            vtxos.any(
              (v) =>
                  v.id == movement.outputVtxoIds.single &&
                  (v.state is bark.SpendableVtxoState ||
                      v.state is bark.SpentVtxoState ||
                      v.state is bark.ExitedVtxoState),
            )) {
          status = ArkOperationStatus.succeeded;
        }
      }
    }
    if (operation.kind == ArkOperationKind.renewal) {
      final vtxos = await _run('reconcile-renewal', _wallet.allVtxos);
      final history = await _run('reconcile-renewal-history', _wallet.history);
      if (operation.actualIds.isNotEmpty &&
          history.any(
            (m) =>
                m.subsystemName == 'bark.round' &&
                m.subsystemKind == 'refresh' &&
                m.status == 'successful' &&
                operation.actualIds.every(m.inputVtxoIds.contains) &&
                m.outputVtxoIds.isNotEmpty &&
                m.outputVtxoIds.every((id) => vtxos.any((v) => v.id == id)),
          )) {
        status = ArkOperationStatus.succeeded;
      }
    }
    if (operation.kind == ArkOperationKind.claim &&
        reference != null &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(reference) &&
        operation.actualIds.isNotEmpty) {
      final exits = await _run('reconcile-claim', _wallet.getExitVtxos);
      final claimed = {
        for (final exit in exits)
          if (exit.state case bark.ClaimedExitState(:final txid))
            exit.vtxoId: txid,
      };
      if (operation.actualIds.any(
        (id) => claimed[id] != null && claimed[id] != reference,
      )) {
        status = ArkOperationStatus.conflicted;
      } else if (operation.actualIds.every((id) => claimed[id] == reference)) {
        status = ArkOperationStatus.succeeded;
      }
    }
    if (status == null) return null;
    return ArkOperation(
      id: operation.id,
      kind: operation.kind,
      status: status,
      chainSource: operation.chainSource,
      configGeneration: operation.configGeneration,
      nativeReference: reference,
      actualIds: operation.actualIds,
      skippedIds: operation.skippedIds,
      boardFunding: operation.boardFunding,
      claimRecovery: operation.claimRecovery,
    );
  }

  @override
  void close() {
    try {
      _wallet.dispose();
    } finally {
      _onchain.dispose();
    }
  }
}

ArkRecoveryStatus mapBarkRecovery(bark.RecoveryStatus value) => switch (value) {
  bark.CompletedRecoveryStatus(:final report) =>
    report.isComplete
        ? ArkRecoveryStatus.complete
        : ArkRecoveryStatus.incomplete,
  bark.FailedRecoveryStatus() => ArkRecoveryStatus.failed,
  bark.NotRunRecoveryStatus() => ArkRecoveryStatus.notRun,
  _ => ArkRecoveryStatus.unknown,
};

/// Only mutable native entry points are replaceable by an internal test seam.
abstract interface class BarkOpenBoundary {
  bark.DatadirInfo? inspect(String datadir);
  bool hasData(String datadir);
  Future<bark.OnchainWallet> openOnchain({
    required bark.Network network,
    required String mnemonic,
    required bark.Config config,
    required String datadir,
  });
  Future<bark.Wallet> openWallet({
    required bark.Network network,
    required String mnemonicOrSeed,
    required bark.Config config,
    required bark.WalletOpenArgs args,
  });
}

final class FfiBarkOpenBoundary implements BarkOpenBoundary {
  const FfiBarkOpenBoundary();
  @override
  bark.DatadirInfo? inspect(String datadir) =>
      bark.readDatadirInfo(datadir: datadir);
  @override
  bool hasData(String datadir) =>
      Directory(datadir).existsSync() &&
      Directory(datadir).listSync().isNotEmpty;
  @override
  Future<bark.OnchainWallet> openOnchain({
    required bark.Network network,
    required String mnemonic,
    required bark.Config config,
    required String datadir,
  }) => bark.OnchainWallet.default_(
    network: network,
    mnemonic: mnemonic,
    config: config,
    datadir: datadir,
  );
  @override
  Future<bark.Wallet> openWallet({
    required bark.Network network,
    required String mnemonicOrSeed,
    required bark.Config config,
    required bark.WalletOpenArgs args,
  }) => bark.Wallet.open(
    network: network,
    mnemonicOrSeed: mnemonicOrSeed,
    config: config,
    args: args,
  );
}

/// Public consistency identity only, from the scoped dedicated child at m/350h.
/// The four-byte fingerprint is not collision-resistant authentication.
/// Dart strings/key objects cannot be guaranteed to be zeroized.
String deriveBarkChildFingerprint(String words) {
  try {
    final mnemonic = Mnemonic.fromSentence(
      words,
      Language.english,
      passphrase: '',
    );
    final purpose = Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed))
        .deriveHardened(350);
    return purpose.fingerprint
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  } on MnemonicException {
    throw const ArkBoundaryException(
      ArkValidationFailure(ArkFailureReason.identityMismatch),
    );
  }
}
