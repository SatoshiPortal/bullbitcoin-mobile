import 'dart:convert';
import 'dart:io';

import 'package:primitives/primitives.dart';

import '../../ark.dart';
import '../rust/api/exit.dart' as exit;
import '../rust/api/wallet.dart' as scuttle;
import '../rust/frb_generated.dart';
import 'ark_native_session.dart';

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
      return _ScuttleSession(wallet, stages, isNew: !exists);
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
  final bool _isNew;

  const _ScuttleSession(this._wallet, this._stages, {required this._isNew});

  @override
  Future<void> close() => _wallet.close();

  @override
  Future<void> synchronizeStage(String name) async {
    if (name != 'initial-scan' || !_isNew) _unsupported();
    await _stages.run(name, _wallet.initialScan);
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
        _wallet.refreshExitInventory,
      ))
        _projectExit(item),
    ];
    return ArkSnapshot(
      account: account,
      revision: revision,
      observedAt: now,
      tipHeight: native.tipHeight,
      stale: true,
      spendable: previousRecovery == ArkRecoveryStatus.complete
          ? Sats(native.lastKnownSpendableSats)
          : null,
      vtxos: [
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
          ),
      ],
      operations: operations,
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
    if (request is! ArkAddressReceiveRequest) _unsupported();
    return ArkReceiveDestination(
      kind: ArkDestinationKind.ark,
      value: await _stages.run('scuttle-receive', _wallet.newArkAddress),
    );
  }

  @override
  Future<DateTime> nextRoundStart() async => _unsupported();

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

  @override
  Future<List<String>> renewalCandidates() async => _unsupported();

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

  @override
  Future<ArkOperation?> reconcile(ArkOperation operation) async {
    final txid = operation.nativeReference;
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
