import 'dart:convert';
import 'dart:io';

import 'package:primitives/primitives.dart';

import '../../ark.dart';
import '../rust/api/exit.dart' as exit;
import '../rust/api/payments.dart' as scuttle;
import '../rust/api/wallet.dart' as scuttle;
import '../rust/frb_generated.dart';
import 'ark_native_session.dart';
import 'scuttle_mapping.dart';

/// Opt-in debug adapter. It never delegates an unsupported operation to Bark.
final class ScuttleNativeOpener implements ArkNativeOpener {
  static Future<void>? _initialization;

  const ScuttleNativeOpener();

  @override
  bool datadirExists(String datadir) =>
      Directory(datadir).existsSync() &&
      Directory(datadir).listSync().isNotEmpty;

  @override
  Future<ArkNativeSession> open({
    required ArkAccountConfig config,
    required String datadir,
    required String mnemonic,
    required Fingerprint childFingerprint,
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
    if (config.id.network != BitcoinNetwork.regtest) _unsupported();
    final exists = datadirExists(datadir);
    if ((!exists && (!create || nativePreviouslyAdmitted)) ||
        (expectedFingerprint != null &&
            expectedFingerprint != childFingerprint.hex)) {
      throw const ArkBoundaryException(ArkRecoveryRequiredFailure());
    }
    await stages.run('scuttle-init', () async {
      await (_initialization ??= ScuttleCore.init());
    });
    final wallet = await stages.run('scuttle-open', () async {
      onNativeAdmission();
      return scuttle.ScuttleWallet.open(
        network: scuttle.ScuttleNetwork.regtest,
        mode: exists ? scuttle.OpenMode.existing : scuttle.OpenMode.new_,
        datadir: datadir,
        serverAddress: config.arkUrl.toString(),
        esploraAddress: chainSource.toString(),
        childMnemonic: mnemonic,
        allowUnreachableServer: false,
      );
    });
    try {
      onOnchainOpened();
      final fingerprint = await stages.run(
        'scuttle-fingerprint',
        wallet.fingerprint,
      );
      if (fingerprint != childFingerprint.hex) {
        throw const ArkBoundaryException(
          ArkValidationFailure(ArkFailureReason.identityMismatch),
        );
      }
      final recovery = await stages.run(
        'scuttle-recovery',
        wallet.recoveryStatus,
      );
      onOpened(_recovery(recovery), fingerprint);
      return _ScuttleSession(wallet, stages, config, isNew: !exists);
    } catch (_) {
      await wallet.close();
      rethrow;
    }
  }
}

ArkRecoveryStatus _recovery(scuttle.ScuttleRecoveryStatus status) =>
    switch (status) {
      scuttle.ScuttleRecoveryStatus.unknown => ArkRecoveryStatus.unknown,
      scuttle.ScuttleRecoveryStatus.notRun => ArkRecoveryStatus.notRun,
      scuttle.ScuttleRecoveryStatus.complete => ArkRecoveryStatus.complete,
      scuttle.ScuttleRecoveryStatus.incomplete => ArkRecoveryStatus.incomplete,
      scuttle.ScuttleRecoveryStatus.failed => ArkRecoveryStatus.failed,
    };

Never _unsupported() =>
    throw const ArkBoundaryException(ArkUnavailableFailure());

final class _ScuttleSession
    implements
        ArkNativeLiveBoardSession,
        ArkNativeExitReserveSession,
        ArkNativeExitCpfpSession {
  final scuttle.ScuttleWallet _wallet;
  final ArkStageRunner _stages;
  final ArkAccountConfig _config;
  final bool _isNew;

  const _ScuttleSession(
    this._wallet,
    this._stages,
    this._config, {
    required this._isNew,
  });

  @override
  Future<void> close() => _wallet.close();

  @override
  Future<void> synchronizeStage(String name) async {
    switch (name) {
      case 'initial-scan':
        // The native scan can rebroadcast stored transactions: only a wallet
        // created by this open has none.
        if (!_isNew) _unsupported();
        await _stages.run(name, _wallet.initialScan);
      case 'server':
        await _stages.run(name, _wallet.refreshServer);
      case 'ark':
        await _stages.run(name, _wallet.syncMailbox);
      case 'lightning':
        await _stages.run(name, _wallet.claimLightningReceives);
      case 'rounds':
        await _stages.run(name, _wallet.progressPendingRounds);
      case 'boards':
        await _stages.run(name, _wallet.syncPendingBoards);
      case 'exits-observe':
        await _stages.run(name, _wallet.refreshExitInventory);
      case 'onchain':
        // The reserve is updated only by journaled imports; a general wallet
        // sync would rebroadcast. Verify the locally known reserve instead.
        await _stages.run(name, _wallet.confirmedReserve);
      default:
        _unsupported();
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
    final native = await _stages.run('scuttle-observe', _wallet.observation);
    final exitDetails = [
      for (final item in await _stages.run(
        'scuttle-observe-exits',
        _wallet.exitInventory,
      ))
        _projectExit(item),
    ];
    final rounds = await _stages.run(
      'scuttle-observe-rounds',
      _wallet.pendingRoundStates,
    );
    final receives = await _stages.run(
      'scuttle-observe-receives',
      _wallet.pendingLightningReceives,
    );
    final sends = await _stages.run(
      'scuttle-observe-sends',
      _wallet.pendingLightningSends,
    );
    final history = await _stages.run(
      'scuttle-observe-history',
      _wallet.history,
    );
    final pendingIds = {for (final round in rounds) ...round.inputVtxoIds};
    final vtxos = [
      for (final vtxo in native.vtxos)
        ArkVtxo(
          id: vtxo.id,
          amount: Sats(vtxo.amountSats),
          expiryHeight: vtxo.expiryHeight,
          state: switch (vtxo.state) {
            scuttle.ScuttleVtxoState.spendable => ArkVtxoState.spendable,
            scuttle.ScuttleVtxoState.locked => ArkVtxoState.locked,
            scuttle.ScuttleVtxoState.spent => ArkVtxoState.spent,
            scuttle.ScuttleVtxoState.exited => ArkVtxoState.exited,
          },
          anchor: vtxo.id,
          pendingRound: pendingIds.contains(vtxo.id),
        ),
    ];
    final liveExits = exitDetails.where(
      (item) =>
          item.status == ArkExitStatus.claimable ||
          item.status == ArkExitStatus.pending ||
          item.status == ArkExitStatus.submitted,
    );
    return ArkSnapshot(
      account: account,
      revision: revision,
      observedAt: now,
      tipHeight: native.tipHeight,
      stale: previousRecovery != ArkRecoveryStatus.complete,
      spendable: previousRecovery == ArkRecoveryStatus.complete
          ? Sats(native.spendableSats)
          : null,
      pending: Sats(native.pendingSats),
      pendingBoardBalance: Sats(native.pendingBoardSats),
      confirmedReserve: Sats(native.confirmedReserveSats),
      vtxoCompleteness: previousRecovery == ArkRecoveryStatus.complete
          ? ArkSectionCompleteness.complete
          : ArkSectionCompleteness.incomplete,
      usingFallback: chainSource != _config.primaryEsploraUrl,
      serverInfo: switch (native.server) {
        final info? => ArkServerInfo(
          publicKey: info.publicKey,
          roundIntervalSeconds: info.roundIntervalSecs.toInt(),
          vtxoLifetimeBlocks: info.vtxoLifetimeBlocks,
          minimumBoard: Sats(info.minBoardSats),
          maximumVtxo: switch (info.maxVtxoSats) {
            final amount? => Sats(amount),
            null => null,
          },
          boardConfirmations: info.boardConfirmations,
        ),
        null => null,
      },
      vtxos: vtxos,
      operations: operations,
      pendingLightningCount: receives.length + sends.length,
      pendingRoundCount: rounds.length,
      movements: [
        for (final movement in history) projectScuttleMovement(movement),
      ],
      renewal: pendingIds.isNotEmpty
          ? ArkRenewalStatus.delegated
          : vtxos.any(
              (v) => v.renewalDueAt(
                native.tipHeight,
                _config.renewalThresholdBlocks,
              ),
            )
          ? ArkRenewalStatus.due
          : ArkRenewalStatus.current,
      obligations:
          native.pendingSats > BigInt.zero ||
              native.pendingBoardSats > BigInt.zero ||
              native.confirmedReserveSats > BigInt.zero ||
              liveExits.isNotEmpty ||
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
      exitDetails: exitDetails,
      exits: exitDetails.any((item) => item.status == ArkExitStatus.claimable)
          ? ArkExitStatus.claimable
          : exitDetails.any(
              (item) =>
                  item.status == ArkExitStatus.pending ||
                  item.status == ArkExitStatus.submitted,
            )
          ? ArkExitStatus.pending
          : ArkExitStatus.none,
      recovery: previousRecovery,
    );
  }

  @override
  Future<String> reserveAddress() =>
      _stages.run('scuttle-reserve-address', _wallet.reserveAddress);

  @override
  Future<bool> verifyInitialExitReserve(
    ArkExitReserveFunding funding,
    String reserveAddress,
  ) async =>
      await _stages.run(
        'scuttle-verify-reserve',
        () => _wallet.verifyRegtestReserveFunding(
          txid: funding.txid,
          destination: reserveAddress,
          amountSats: funding.amount.value,
        ),
      ) !=
      null;

  @override
  Future<bool> importInitialExitReserve(
    ArkExitReserveFunding funding,
    String reserveAddress,
  ) async =>
      await _stages.run(
        'scuttle-import-reserve',
        () => _wallet.importInitialRegtestReserveFunding(
          txid: funding.txid,
          destination: reserveAddress,
          amountSats: funding.amount.value,
        ),
      ) !=
      null;

  @override
  Future<List<ArkExitCpfpStep>> dueExitCpfp(List<String> exitIds) async => [
    for (final step in await _stages.run(
      'scuttle-due-exit-cpfp',
      () => _wallet.dueRegtestExitCpfp(vtxoIds: exitIds),
    ))
      (vtxoId: step.vtxoId, parentTxid: step.parentTxid),
  ];

  @override
  Future<ArkExitCpfpCandidate> prepareExitCpfp(
    ArkExitCpfpStep step,
    FeeRate rate,
    Sats remainingFee,
  ) async {
    final child = await _stages.run(
      'scuttle-prepare-exit-cpfp',
      () => _wallet.prepareRegtestExitCpfp(
        vtxoId: step.vtxoId,
        exitTxid: step.parentTxid,
        feeRateSatPerVb: _claimRate(rate),
        remainingFeeSats: remainingFee.value,
      ),
    );
    if (child.exitTxid != step.parentTxid) {
      throw const ArkBoundaryException(ArkValidationFailure());
    }
    return (
      evidence: (
        txid: child.childTxid,
        raw: _encodeTransaction(child.rawTransaction),
        fee: Sats(child.feeSats),
      ),
      reserveInputs: child.reserveInputs,
    );
  }

  @override
  Future<void> deliverExitCpfp(
    ArkExitCpfpStep step,
    ArkExitCpfpEvidence evidence,
  ) => _stages.run(
    'scuttle-deliver-exit-cpfp',
    () => _wallet.deliverRegtestExitCpfp(
      vtxoId: step.vtxoId,
      exitTxid: step.parentTxid,
      childTxid: evidence.txid,
      rawTransaction: _decodeTransaction(evidence.raw),
      admittedFeeSats: evidence.fee.value,
    ),
  );

  @override
  Future<bool> importExitCpfpChange(ArkExitCpfpEvidence evidence) async =>
      await _stages.run(
        'scuttle-import-exit-change',
        () => _wallet.importConfirmedRegtestCpfpChange(
          childTxid: evidence.txid,
          rawTransaction: _decodeTransaction(evidence.raw),
        ),
      ) !=
      null;

  static String _encodeTransaction(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _decodeTransaction(String raw) {
    if (raw.isEmpty ||
        raw.length.isOdd ||
        raw.length > 200000 ||
        !RegExp(r'^[0-9a-f]+$').hasMatch(raw)) {
      throw const ArkBoundaryException(ArkValidationFailure());
    }
    return [
      for (var i = 0; i < raw.length; i += 2)
        int.parse(raw.substring(i, i + 2), radix: 16),
    ];
  }

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
          value: await _stages.run('scuttle-receive', _wallet.newArkAddress),
        );
      case ArkBolt11ReceiveRequest(
        :final amount,
        :final description,
        :final expirySeconds,
      ):
        // The bridge creates invoices from an amount alone.
        if ((description != null && description.isNotEmpty) ||
            expirySeconds != null) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.unsupportedMethod),
          );
        }
        final fee = await _stages.run(
          'scuttle-receive-fee',
          () => _wallet.estimateLightningReceiveFee(amountSats: amount.value),
        );
        if (isScuttleDust(fee.netSats)) {
          throw const ArkBoundaryException(
            ArkValidationFailure(ArkFailureReason.dust),
          );
        }
        final invoice = await _stages.run(
          'scuttle-receive-bolt11',
          () => _wallet.createLightningInvoice(amountSats: amount.value),
        );
        return ArkReceiveDestination(
          kind: ArkDestinationKind.bolt11,
          value: invoice.invoice,
          net: Sats(fee.netSats),
          fee: Sats(fee.feeSats),
        );
    }
  }

  @override
  Future<DateTime> nextRoundStart() async => scuttleRoundStart(
    await _stages.run('scuttle-next-round', _wallet.nextRoundStartTime),
  );

  @override
  Future<ArkQuote> estimate({
    required ArkSnapshot snapshot,
    required ArkQuoteRequest request,
    required String id,
    required Uri chainSource,
    required int configGeneration,
    required DateTime now,
  }) async {
    if (request is ArkEmergencyExitQuoteRequest) {
      return _estimateExit(
        snapshot: snapshot,
        request: request,
        id: id,
        chainSource: chainSource,
        configGeneration: configGeneration,
        now: now,
      );
    }
    if (request case ArkClaimQuoteRequest(reserveSweepFeeRate: final rate?)) {
      final tip = snapshot.tipHeight;
      if (tip == null || request.maxFee.value <= BigInt.zero) {
        throw const ArkBoundaryException(ArkValidationFailure());
      }
      final review = await _stages.run(
        'scuttle-review-mixed-claim',
        () => _wallet.reviewRegtestMixedClaim(
          vtxoIds: request.ids,
          destination: request.destination,
          feeRateSatPerVb: _claimRate(rate),
          maxFeeSats: request.maxFee.value,
        ),
      );
      return ArkQuote(
        id: id,
        account: snapshot.account,
        generation: snapshot.revision,
        chainSource: chainSource,
        configGeneration: configGeneration,
        kind: ArkOperationKind.claim,
        amount: Sats(review.amountSats),
        fee: Sats(review.feeSats),
        net: Sats(review.amountSats - review.feeSats),
        selectedIds: request.ids,
        reserveOutpoints: [for (final coin in review.reserve) coin.outpoint],
        destination: request.destination,
        destinationKind: ArkDestinationKind.bitcoin,
        observedTip: tip,
        validUntil: now.add(const Duration(minutes: 2)),
        feeRate: rate,
        confirmedReserveExposure: Sats(
          review.reserve.fold(
            BigInt.zero,
            (sum, coin) => sum + coin.amountSats,
          ),
        ),
        maxClaimFee: request.maxFee,
      );
    }
    if (request is ArkPaymentQuoteRequest) {
      return _estimateSpend(
        snapshot: snapshot,
        request: request,
        id: id,
        chainSource: chainSource,
        configGeneration: configGeneration,
        now: now,
      );
    }
    if (request is ArkRenewalQuoteRequest) {
      final tip = _tip(snapshot);
      final estimate = await _stages.run(
        'scuttle-estimate-renewal',
        () => _wallet.estimateRefreshFee(vtxoIds: request.ids),
      );
      final selected = validateScuttleEstimate(
        estimate: estimate,
        tip: tip,
        vtxos: snapshot.vtxos,
        spendable: snapshot.spendable,
        renewalIds: request.ids,
      );
      return _spendQuote(
        snapshot: snapshot,
        id: id,
        chainSource: chainSource,
        configGeneration: configGeneration,
        now: now,
        kind: ArkOperationKind.renewal,
        estimate: estimate,
        selected: selected,
        tip: tip,
      );
    }
    if (request is! ArkBoardQuoteRequest) _unsupported();
    final anchor = request.anchor;
    final terms = await _stages.run(
      'scuttle-board-terms',
      () => _wallet.boardTerms(
        amountSats: request.amount.value,
        anchor: anchor == null
            ? null
            : scuttle.ScuttleBoardAnchor(
                height: anchor.height,
                hash: anchor.hash,
              ),
      ),
    );
    final observedTip = snapshot.tipHeight;
    if (terms.grossSats != request.amount.value ||
        terms.feeSats + terms.netSats != terms.grossSats ||
        terms.netSats <= BigInt.zero ||
        (observedTip != null && terms.tipHeight < observedTip)) {
      throw const ArkBoundaryException(ArkValidationFailure());
    }
    return ArkQuote(
      id: id,
      account: snapshot.account,
      generation: snapshot.revision,
      chainSource: chainSource,
      configGeneration: configGeneration,
      kind: ArkOperationKind.board,
      amount: request.amount,
      fee: Sats(terms.feeSats),
      net: Sats(terms.netSats),
      observedTip: terms.tipHeight,
      validUntil: now.add(const Duration(minutes: 2)),
      boardEvidence: ArkBoardQuoteEvidence(
        serverKey: terms.serverKey,
        tipHash: terms.tipHash,
        requiredConfirmations: terms.requiredConfirmations,
      ),
    );
  }

  static int _tip(ArkSnapshot snapshot) =>
      snapshot.tipHeight ??
      (throw const ArkBoundaryException(
        ArkUnavailableFailure(ArkFailureReason.unavailable),
      ));

  Future<ArkQuote> _estimateSpend({
    required ArkSnapshot snapshot,
    required ArkPaymentQuoteRequest request,
    required String id,
    required Uri chainSource,
    required int configGeneration,
    required DateTime now,
  }) async {
    final tip = _tip(snapshot);
    final destination = request.destination;
    final amount = request.amount.value;
    final parsed = await _stages.run(
      'scuttle-parse-payment',
      () => _wallet.parsePaymentRequest(payment: destination.value),
    );
    final kind = validateScuttlePaymentRequest(
      destination,
      request.amount,
      parsed,
    );
    final estimate = await _stages.run(
      'scuttle-estimate-payment',
      () => switch (kind) {
        scuttle.ScuttlePaymentKind.ark => _wallet.estimateArkPaymentFee(
          amountSats: amount,
        ),
        scuttle.ScuttlePaymentKind.bolt11 =>
          _wallet.estimateLightningPaymentFee(
            invoice: destination.value,
            amountSats: amount,
          ),
        scuttle.ScuttlePaymentKind.bitcoin => _wallet.estimateOnchainSendFee(
          address: destination.value,
          amountSats: amount,
        ),
      },
    );
    final selected = validateScuttleEstimate(
      estimate: estimate,
      tip: tip,
      vtxos: snapshot.vtxos,
      spendable: snapshot.spendable,
    );
    return _spendQuote(
      snapshot: snapshot,
      id: id,
      chainSource: chainSource,
      configGeneration: configGeneration,
      now: now,
      kind: ArkOperationKind.payment,
      estimate: estimate,
      selected: selected,
      tip: tip,
      destination: destination,
    );
  }

  ArkQuote _spendQuote({
    required ArkSnapshot snapshot,
    required String id,
    required Uri chainSource,
    required int configGeneration,
    required DateTime now,
    required ArkOperationKind kind,
    required scuttle.ScuttleFeeEstimate estimate,
    required List<String> selected,
    required int tip,
    ArkPaymentDestination? destination,
  }) {
    if (estimate.feeSats < BigInt.zero ||
        estimate.grossSats < estimate.netSats ||
        ((kind == ArkOperationKind.renewal ||
                destination?.kind == ArkDestinationKind.ark) &&
            isScuttleDust(estimate.netSats))) {
      throw ArkBoundaryException(
        ArkValidationFailure(
          estimate.feeSats < BigInt.zero ||
                  estimate.grossSats < estimate.netSats
              ? ArkFailureReason.validation
              : ArkFailureReason.dust,
        ),
      );
    }
    return ArkQuote(
      id: id,
      account: snapshot.account,
      generation: snapshot.revision,
      chainSource: chainSource,
      configGeneration: configGeneration,
      kind: kind,
      amount: Sats(estimate.grossSats),
      fee: Sats(estimate.feeSats),
      net: Sats(estimate.netSats),
      selectedIds: selected,
      destination: destination?.value,
      destinationKind: destination?.kind,
      observedTip: tip,
      validUntil: now.add(const Duration(minutes: 2)),
    );
  }

  Future<ArkQuote> _estimateExit({
    required ArkSnapshot snapshot,
    required ArkEmergencyExitQuoteRequest request,
    required String id,
    required Uri chainSource,
    required int configGeneration,
    required DateTime now,
  }) async {
    final tip = snapshot.tipHeight;
    // The smoke wallet can price individually proven, finalized boards. A
    // cached spendable label alone is not sufficient to select an exit.
    final finalized = {
      for (final operation in snapshot.operations)
        if (operation.kind == ArkOperationKind.board &&
            operation.status == ArkOperationStatus.succeeded &&
            operation.boardFunding?.scuttleToken != null &&
            operation.chainSource == chainSource)
          ...operation.actualIds,
    };
    final selected = [
      for (final vtxo in snapshot.vtxos)
        if (request.ids.contains(vtxo.id) &&
            finalized.contains(vtxo.id) &&
            vtxo.state == ArkVtxoState.spendable &&
            !vtxo.pendingRound &&
            tip != null &&
            vtxo.expiryHeight > tip)
          vtxo,
    ];
    if (tip == null ||
        snapshot.recovery != ArkRecoveryStatus.complete ||
        selected.length != request.ids.length ||
        selected.map((vtxo) => vtxo.id).toSet().length != request.ids.length) {
      throw const ArkBoundaryException(
        ArkValidationFailure(ArkFailureReason.invalidSelection),
      );
    }
    final rate = request.feeRate?.satsPerVbyte;
    if (rate != null && (rate < 1 || rate > 100000 || rate != rate.round())) {
      throw const ArkBoundaryException(ArkValidationFailure());
    }
    Future<exit.ScuttleExitFeeEstimate> price(BigInt? rate) => _stages.run(
      'scuttle-estimate-exit',
      () => _wallet.estimateExit(
        vtxoIds: request.ids,
        feeRateSatPerVb: rate,
        destination: request.destination,
      ),
    );
    var exactRate = rate == null ? null : BigInt.from(rate);
    var terms = await price(exactRate);
    if (exactRate == null) {
      final perVbyte = BigInt.from(250);
      exactRate =
          (terms.broadcastRateSatPerKwu + perVbyte - BigInt.one) ~/ perVbyte;
      if (exactRate < BigInt.one || exactRate > BigInt.from(100000)) {
        throw const ArkBoundaryException(ArkValidationFailure());
      }
      terms = await price(exactRate);
    }
    final sum = selected.fold(
      BigInt.zero,
      (sum, vtxo) => sum + vtxo.amount.value,
    );
    final claimFee = terms.claimFeeSats;
    final ceiling =
        request.maxClaimFee?.value ??
        (claimFee > BigInt.zero ? claimFee * BigInt.two : BigInt.one);
    if (claimFee >= sum ||
        claimFee > ceiling ||
        terms.exitBroadcastFeeSats + claimFee != terms.totalFeeSats ||
        terms.broadcastRateSatPerKwu != exactRate * BigInt.from(250)) {
      throw const ArkBoundaryException(ArkValidationFailure());
    }
    final confirmed = await _stages.run(
      'scuttle-exit-reserve',
      _wallet.confirmedReserve,
    );
    return ArkQuote(
      id: id,
      account: snapshot.account,
      generation: snapshot.revision,
      chainSource: chainSource,
      configGeneration: configGeneration,
      kind: ArkOperationKind.emergencyExit,
      amount: Sats(sum),
      fee: Sats(terms.exitBroadcastFeeSats),
      net: Sats(sum - claimFee),
      selectedIds: request.ids,
      destination: request.destination,
      destinationKind: ArkDestinationKind.bitcoin,
      observedTip: tip,
      validUntil: now.add(const Duration(minutes: 2)),
      feeRate: FeeRate(exactRate.toDouble()),
      claimFee: Sats(claimFee),
      maxClaimFee: Sats(ceiling),
      confirmedReserveExposure: Sats(
        confirmed.fold(BigInt.zero, (sum, coin) => sum + coin.amountSats),
      ),
    );
  }

  @override
  Future<ArkOperation> execute(ArkQuote quote, String operationId) async {
    // A native error after admission ("Payment outcome unknown", "Refresh
    // outcome unknown") propagates as an exception: the client records
    // `outcomeUnknown` for any non-Error thrown here and never retries.
    switch (quote.kind) {
      case ArkOperationKind.payment:
        return _executePayment(quote, operationId);
      case ArkOperationKind.renewal:
        final round = await _stages.run(
          'scuttle-renew',
          () => _wallet.refreshVtxosDelegated(vtxoIds: quote.selectedIds),
        );
        return ArkOperation(
          id: operationId,
          kind: quote.kind,
          status: round == null
              ? ArkOperationStatus.outcomeUnknown
              : ArkOperationStatus.pending,
          chainSource: quote.chainSource,
          configGeneration: quote.configGeneration,
          nativeReference: round?.toString(),
          actualIds: quote.selectedIds,
        );
      default:
        break;
    }
    final exposure = quote.confirmedReserveExposure;
    if (quote.kind != ArkOperationKind.emergencyExit ||
        quote.account.network != BitcoinNetwork.regtest ||
        quote.destination == null ||
        exposure == null ||
        exposure.value < quote.fee.value) {
      _unsupported();
    }
    await _stages.run(
      'scuttle-start-reviewed-exit',
      () => _wallet.startExit(vtxoIds: quote.selectedIds),
    );
    return ArkOperation(
      id: operationId,
      kind: quote.kind,
      status: ArkOperationStatus.pending,
      chainSource: quote.chainSource,
      configGeneration: quote.configGeneration,
      actualIds: quote.selectedIds,
    );
  }

  Future<ArkOperation> _executePayment(
    ArkQuote quote,
    String operationId,
  ) async {
    final destination = quote.destination;
    final kind = quote.destinationKind;
    if (destination == null || kind == null) {
      throw const ArkBoundaryException(
        ArkValidationFailure(ArkFailureReason.validation),
      );
    }
    // The payment API takes the destination amount, not the gross.
    final amount = quote.net.value;
    final String reference = switch (kind) {
      ArkDestinationKind.ark => (await _stages.run(
        'scuttle-send-ark',
        () => _wallet.sendArk(address: destination, amountSats: amount),
      )).toString(),
      ArkDestinationKind.bolt11 => await _stages.run(
        'scuttle-send-lightning',
        () => _wallet.payLightningInvoice(
          invoice: destination,
          amountSats: amount,
        ),
      ),
      ArkDestinationKind.bitcoin => (await _stages.run(
        'scuttle-send-onchain',
        () => _wallet.sendOnchain(address: destination, amountSats: amount),
      )).movementId.toString(),
    };
    return ArkOperation(
      id: operationId,
      kind: quote.kind,
      status: ArkOperationStatus.pending,
      chainSource: quote.chainSource,
      configGeneration: quote.configGeneration,
      nativeReference: reference,
      actualIds: quote.selectedIds,
    );
  }

  @override
  Future<List<String>> renewalCandidates() =>
      _stages.run('scuttle-renewal-candidates', _wallet.vtxosToRefresh);

  @override
  Future<ArkBoardFundingDetails> boardFunding() async {
    final funding = await _stages.run(
      'scuttle-board-funding',
      _wallet.prepareBoard,
    );
    return ArkBoardFundingDetails.scuttle(
      address: funding.address,
      token: funding.token,
      expiryHeight: funding.expiryHeight,
    );
  }

  @override
  Future<String> registerBoard(
    ArkRegisterBoard submission,
    ArkBoardFundingDetails funding,
  ) async {
    final token = funding.scuttleToken;
    if (token == null) {
      throw const ArkBoundaryException(ArkValidationFailure());
    }
    final result = await _stages.run(
      'scuttle-register-board',
      () => _wallet.registerBoard(
        fundingToken: token,
        unsignedPsbt: base64Decode(submission.unfinalisedPsbt),
      ),
    );
    return result.fundingTxid;
  }

  @override
  Future<ArkClaimTransaction> prepareClaim(ArkQuote quote) async {
    final destination = quote.destination;
    final rate = quote.feeRate;
    if (quote.kind != ArkOperationKind.claim ||
        destination == null ||
        rate == null ||
        quote.reserveOutpoints.isEmpty) {
      _unsupported();
    }
    final signed = await _stages.run(
      'scuttle-prepare-mixed-claim',
      () => _wallet.prepareRegtestMixedClaim(
        vtxoIds: quote.selectedIds,
        destination: destination,
        reserveOutpoints: quote.reserveOutpoints,
        feeRateSatPerVb: _claimRate(rate),
        expectedAmountSats: quote.amount.value,
        expectedFeeSats: quote.fee.value,
      ),
    );
    return ArkClaimTransaction(
      rawTransaction: _encodeTransaction(signed.rawTransaction),
      signedPsbt: base64Encode(signed.signedPsbt),
      actualIds: quote.selectedIds,
      skippedIds: [],
      inputAmounts: {
        for (final input in signed.inputs)
          input.vtxoId: input.amountSats.toString(),
      },
      fee: signed.feeSats.toString(),
    );
  }

  static BigInt _claimRate(FeeRate rate) {
    final value = rate.satsPerVbyte;
    if (value < 1 || value > 100000 || value != value.round()) {
      throw const ArkBoundaryException(ArkValidationFailure());
    }
    return BigInt.from(value);
  }

  @override
  Future<String> broadcast(String rawTransaction) async => _unsupported();

  Future<ArkOperationStatus?> _reconcileSpend(
    ArkOperation operation,
    String? reference,
  ) async {
    if (reference == null) return null;
    if (operation.kind == ArkOperationKind.renewal) {
      final rounds = await _stages.run(
        'scuttle-reconcile-rounds',
        _wallet.pendingRoundStates,
      );
      final observed = await _stages.run(
        'scuttle-reconcile-vtxos',
        _wallet.observation,
      );
      final history = await _stages.run(
        'scuttle-reconcile-renewal-history',
        _wallet.history,
      );
      return scuttleRenewalOutcome(
        reference: reference,
        actualIds: operation.actualIds,
        rounds: rounds,
        vtxos: observed.vtxos,
        history: history,
      );
    }
    if (isScuttleMovementReference(reference)) {
      final history = await _stages.run(
        'scuttle-reconcile-movement',
        _wallet.history,
      );
      ArkOperationStatus? status;
      for (final movement in history.where(
        (m) => m.id.toString() == reference,
      )) {
        status = scuttlePaymentMovementOutcome(movement.status);
      }
      return status;
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(reference)) return null;
    return scuttleLightningSendOutcome(
      await _stages.run(
        'scuttle-reconcile-lightning',
        () => _wallet.lightningSendStatus(paymentHash: reference),
      ),
    );
  }

  @override
  Future<ArkOperation?> reconcile(ArkOperation operation) async {
    final txid = operation.nativeReference;
    if (operation.kind == ArkOperationKind.payment ||
        operation.kind == ArkOperationKind.renewal) {
      final status = await _reconcileSpend(operation, txid);
      if (status == null) return null;
      return ArkOperation(
        id: operation.id,
        kind: operation.kind,
        status: status,
        chainSource: operation.chainSource,
        configGeneration: operation.configGeneration,
        nativeReference: txid,
        actualIds: operation.actualIds,
        skippedIds: operation.skippedIds,
        boardFunding: operation.boardFunding,
        claimRecovery: operation.claimRecovery,
      );
    }
    if (operation.kind != ArkOperationKind.board ||
        operation.status != ArkOperationStatus.pending ||
        operation.boardFunding?.scuttleToken == null ||
        txid == null) {
      return null;
    }
    final vtxoId = await _stages.run(
      'scuttle-finalize-board',
      () => _wallet.finalizeRegtestBoard(fundingTxid: txid),
    );
    if (vtxoId == null) return null;
    return ArkOperation(
      id: operation.id,
      kind: operation.kind,
      status: ArkOperationStatus.succeeded,
      chainSource: operation.chainSource,
      configGeneration: operation.configGeneration,
      nativeReference: txid,
      actualIds: [vtxoId],
      boardFunding: operation.boardFunding,
    );
  }
}

ArkExit _projectExit(exit.ScuttleExit item) => ArkExit(
  id: item.vtxoId,
  amount: Sats(item.amountSats),
  status: switch (item.state) {
    exit.ScuttleExitState.start ||
    exit.ScuttleExitState.processing ||
    exit.ScuttleExitState.awaitingDelta => ArkExitStatus.pending,
    exit.ScuttleExitState.claimable => ArkExitStatus.claimable,
    exit.ScuttleExitState.claimInProgress => ArkExitStatus.submitted,
    exit.ScuttleExitState.claimed => ArkExitStatus.claimed,
    exit.ScuttleExitState.vtxoAlreadySpent ||
    exit.ScuttleExitState.vtxoSwept => ArkExitStatus.failed,
    exit.ScuttleExitState.canceled => ArkExitStatus.none,
  },
  claimableHeight: item.claimableHeight,
  claimTxid: item.claimTxid,
);
