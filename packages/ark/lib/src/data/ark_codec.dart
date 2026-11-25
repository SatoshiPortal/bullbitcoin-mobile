import 'dart:convert';

import 'package:primitives/primitives.dart';

import '../../ark.dart';

Map<String, Object?> decodeMap(String value) => _decode(
  () => (jsonDecode(value) as Map<String, dynamic>).cast<String, Object?>(),
);
Map<String, Object?> mapValue(Object? value) =>
    (value as Map).cast<String, Object?>();
List<String> strings(Object? value) => (value as List).cast<String>();
Sats sats(Object? value) => Sats(BigInt.parse(value as String));
Sats? nullableSats(Object? value) => value == null ? null : sats(value);
List<Map<String, Object?>> maps(Object? value) =>
    (value as List).map(mapValue).toList();

Map<String, Object?> accountToJson(ArkAccountId id) => {
  'parent': id.parent.hex,
  'network': id.network.name,
  'server': id.serverIdentity,
};
ArkAccountId accountFromJson(Map<String, Object?> m) => _decode(
  () => ArkAccountId(
    parent: Fingerprint(m['parent'] as String),
    network: BitcoinNetwork.fromName(m['network'] as String),
    serverIdentity: m['server'] as String,
  ),
);
Map<String, Object?> configToJson(ArkAccountConfig c) => {
  'id': accountToJson(c.id),
  'ark': c.arkUrl.toString(),
  'primary': c.primaryEsploraUrl.toString(),
  'fallback': c.fallbackEsploraUrl?.toString(),
  'threshold': c.renewalThresholdBlocks,
  'generation': 1,
};
ArkAccountConfig configFromJson(Map<String, Object?> m) => _decode(
  () => ArkAccountConfig(
    id: accountFromJson(mapValue(m['id'])),
    arkUrl: Uri.parse(m['ark'] as String),
    primaryEsploraUrl: Uri.parse(m['primary'] as String),
    fallbackEsploraUrl: m['fallback'] == null
        ? null
        : Uri.parse(m['fallback'] as String),
    renewalThresholdBlocks: m['threshold'] as int,
  ),
);
Map<String, Object?> vtxoToJson(ArkVtxo v) => {
  'id': v.id,
  'amount': v.amount.toString(),
  'expiry': v.expiryHeight,
  'state': v.state.name,
  'anchor': v.anchor,
  'round': v.pendingRound,
};
ArkVtxo vtxoFromJson(Map<String, Object?> m) => _decode(
  () => ArkVtxo(
    id: m['id'] as String,
    amount: sats(m['amount']),
    expiryHeight: m['expiry'] as int,
    state: ArkVtxoState.values.byName(m['state'] as String),
    anchor: m['anchor'] as String?,
    pendingRound: m['round'] as bool,
  ),
);
Map<String, Object?> movementToJson(ArkMovement v) => {
  'id': v.id,
  'kind': v.kind.name,
  'status': v.status.name,
  'amount': v.amount?.toString(),
  'fee': v.fee?.toString(),
  'createdAt': v.createdAt?.toIso8601String(),
  'txid': v.transactionId,
  'sentTo': v.sentTo,
  'receivedOn': v.receivedOn,
  'completedAt': v.completedAt?.toIso8601String(),
  'inputs': v.inputVtxoIds,
  'outputs': v.outputVtxoIds,
};
ArkMovement movementFromJson(Map<String, Object?> m) => _decode(
  () => ArkMovement(
    id: m['id'] as String,
    kind: ArkMovementKind.values.byName(m['kind'] as String),
    status: ArkMovementStatus.values.byName(m['status'] as String),
    amount: nullableSats(m['amount']),
    fee: nullableSats(m['fee']),
    createdAt: m['createdAt'] == null
        ? null
        : DateTime.parse(m['createdAt'] as String),
    transactionId: m['txid'] as String?,
    sentTo: m['sentTo'] == null ? const [] : strings(m['sentTo']),
    receivedOn: m['receivedOn'] == null ? const [] : strings(m['receivedOn']),
    completedAt: m['completedAt'] == null
        ? null
        : DateTime.parse(m['completedAt'] as String),
    inputVtxoIds: strings(m['inputs']),
    outputVtxoIds: strings(m['outputs']),
  ),
);
Map<String, Object?> serverToJson(ArkServerInfo v) => {
  'key': v.publicKey,
  'interval': v.roundIntervalSeconds,
  'lifetime': v.vtxoLifetimeBlocks,
  'minimum': v.minimumBoard?.toString(),
  'maximum': v.maximumVtxo?.toString(),
  'confirmations': v.boardConfirmations,
};
ArkServerInfo serverFromJson(Map<String, Object?> m) => _decode(
  () => ArkServerInfo(
    publicKey: m['key'] as String,
    roundIntervalSeconds: m['interval'] as int?,
    vtxoLifetimeBlocks: m['lifetime'] as int?,
    minimumBoard: nullableSats(m['minimum']),
    maximumVtxo: nullableSats(m['maximum']),
    boardConfirmations: m['confirmations'] as int?,
  ),
);
Map<String, Object?> snapshotToJson(ArkSnapshot v) => {
  'account': accountToJson(v.account),
  'revision': v.revision,
  'observed': v.observedAt.toIso8601String(),
  'tip': v.tipHeight,
  'stale': v.stale,
  'spendable': v.spendable?.toString(),
  'pending': v.pending?.toString(),
  'pendingBoardBalance': v.pendingBoardBalance?.toString(),
  'reserve': v.confirmedReserve?.toString(),
  'vtxos': v.vtxos.map(vtxoToJson).toList(),
  'movements': v.movements.map(movementToJson).toList(),
  'operations': v.operations.map(operationToJson).toList(),
  'vtxoCompleteness': v.vtxoCompleteness.name,
  'exitDetails': v.exitDetails
      .map(
        (e) => <String, Object?>{
          'id': e.id,
          'amount': e.amount.toString(),
          'status': e.status.name,
          'claimableHeight': e.claimableHeight,
          'claimTxid': e.claimTxid,
        },
      )
      .toList(),
  'pendingBoards': v.pendingBoards
      .map(
        (b) => <String, Object?>{
          'id': b.vtxoId,
          'txid': b.fundingTxid,
          'amount': b.amount.toString(),
          'expiry': b.expiryHeight,
        },
      )
      .toList(),
  'server': v.serverInfo == null
      ? null
      : serverToJson(v.serverInfo as ArkServerInfo),
  'renewal': v.renewal.name,
  'exits': v.exits.name,
  'recovery': v.recovery.name,
  'obligations': v.obligations.name,
  'boards': v.pendingBoardCount,
  'lightning': v.pendingLightningCount,
  'rounds': v.pendingRoundCount,
  'reserveAddress': v.reserveAddress,
  'fallback': v.usingFallback,
};
ArkSnapshot snapshotFromJson(Map<String, Object?> m) => _decode(
  () => ArkSnapshot(
    account: accountFromJson(mapValue(m['account'])),
    revision: m['revision'] as int,
    observedAt: DateTime.parse(m['observed'] as String),
    tipHeight: m['tip'] as int?,
    stale: m['stale'] as bool,
    spendable: nullableSats(m['spendable']),
    pending: nullableSats(m['pending']),
    pendingBoardBalance: nullableSats(m['pendingBoardBalance']),
    confirmedReserve: nullableSats(m['reserve']),
    vtxos: maps(m['vtxos']).map(vtxoFromJson).toList(),
    movements: maps(m['movements']).map(movementFromJson).toList(),
    operations: maps(m['operations']).map(operationFromJson).toList(),
    vtxoCompleteness: ArkSectionCompleteness.values.byName(
      m['vtxoCompleteness'] as String,
    ),
    exitDetails: maps(m['exitDetails'])
        .map(
          (e) => ArkExit(
            id: e['id'] as String,
            amount: sats(e['amount']),
            status: ArkExitStatus.values.byName(e['status'] as String),
            claimableHeight: e['claimableHeight'] as int?,
            claimTxid: e['claimTxid'] as String?,
          ),
        )
        .toList(),
    pendingBoards: maps(m['pendingBoards'])
        .map(
          (b) => ArkPendingBoard(
            vtxoId: b['id'] as String,
            fundingTxid: b['txid'] as String,
            amount: sats(b['amount']),
            expiryHeight: b['expiry'] as int?,
          ),
        )
        .toList(),
    serverInfo: m['server'] == null
        ? null
        : serverFromJson(mapValue(m['server'])),
    renewal: ArkRenewalStatus.values.byName(m['renewal'] as String),
    exits: ArkExitStatus.values.byName(m['exits'] as String),
    recovery: ArkRecoveryStatus.values.byName(m['recovery'] as String),
    obligations: ArkObligationStatus.values.byName(m['obligations'] as String),
    pendingBoardCount: m['boards'] as int?,
    pendingLightningCount: m['lightning'] as int?,
    pendingRoundCount: m['rounds'] as int?,
    reserveAddress: m['reserveAddress'] as String?,
    usingFallback: m['fallback'] as bool,
  ),
);
Map<String, Object?> quoteToJson(ArkQuote q) => {
  'id': q.id,
  'account': accountToJson(q.account),
  'generation': q.generation,
  'source': q.chainSource.toString(),
  'configGeneration': q.configGeneration,
  'kind': q.kind.name,
  'amount': q.amount.toString(),
  'fee': q.fee.toString(),
  'net': q.net.toString(),
  'ids': q.selectedIds,
  'reserveOutpoints': q.reserveOutpoints,
  'destination': q.destination,
  'destinationKind': q.destinationKind?.name,
  'tip': q.observedTip,
  'until': q.validUntil.toIso8601String(),
  'rate': q.feeRate?.satsPerVbyte,
  'exposure': q.confirmedReserveExposure?.toString(),
  'maxClaim': q.maxClaimFee?.toString(),
  'claimFee': q.claimFee?.toString(),
  if (q.boardEvidence case final evidence?)
    'boardEvidence': {
      'serverKey': evidence.serverKey,
      'tipHash': evidence.tipHash,
      'confirmations': evidence.requiredConfirmations,
    },
};
ArkQuote quoteFromJson(Map<String, Object?> m) => _decode(
  () => ArkQuote(
    id: m['id'] as String,
    account: accountFromJson(mapValue(m['account'])),
    generation: m['generation'] as int,
    chainSource: Uri.parse(m['source'] as String),
    configGeneration: m['configGeneration'] as int,
    kind: ArkOperationKind.values.byName(m['kind'] as String),
    amount: sats(m['amount']),
    fee: sats(m['fee']),
    net: sats(m['net']),
    selectedIds: strings(m['ids']),
    reserveOutpoints: strings(m['reserveOutpoints']),
    destination: m['destination'] as String?,
    destinationKind: m['destinationKind'] == null
        ? null
        : ArkDestinationKind.values.byName(m['destinationKind'] as String),
    observedTip: m['tip'] as int,
    validUntil: DateTime.parse(m['until'] as String),
    feeRate: m['rate'] == null ? null : FeeRate((m['rate'] as num).toDouble()),
    confirmedReserveExposure: nullableSats(m['exposure']),
    maxClaimFee: nullableSats(m['maxClaim']),
    claimFee: nullableSats(m['claimFee']),
    boardEvidence: switch (m['boardEvidence']) {
      final raw? => _boardQuoteEvidence(mapValue(raw)),
      null => null,
    },
  ),
);
ArkBoardQuoteEvidence _boardQuoteEvidence(Map<String, Object?> m) =>
    ArkBoardQuoteEvidence(
      serverKey: m['serverKey'] as String,
      tipHash: m['tipHash'] as String,
      requiredConfirmations: m['confirmations'] as int,
    );

Map<String, Object?> operationToJson(ArkOperation o) => {
  'id': o.id,
  'kind': o.kind.name,
  'status': o.status.name,
  'source': o.chainSource.toString(),
  'configGeneration': o.configGeneration,
  'reference': o.nativeReference,
  'actual': o.actualIds,
  'skipped': o.skippedIds,
  'claimRecovery': switch (o.claimRecovery) {
    final r? => {
      'txid': r.txid,
      'destination': r.destination,
      'net': r.net.toString(),
      'fee': r.fee.toString(),
    },
    null => null,
  },
  'funding': switch (o.boardFunding) {
    final f? => {
      'address': f.address,
      'index': ?f.keypairIndex,
      'scuttleToken': ?f.scuttleToken,
      'expiry': f.expiryHeight,
    },
    null => null,
  },
};
ArkOperation operationFromJson(Map<String, Object?> m) => _decode(
  () => ArkOperation(
    id: m['id'] as String,
    kind: ArkOperationKind.values.byName(m['kind'] as String),
    status: ArkOperationStatus.values.byName(m['status'] as String),
    chainSource: Uri.parse(m['source'] as String),
    configGeneration: m['configGeneration'] as int,
    nativeReference: m['reference'] as String?,
    actualIds: strings(m['actual']),
    skippedIds: strings(m['skipped']),
    claimRecovery: switch (m['claimRecovery']) {
      final r? => _claimRecovery(mapValue(r)),
      null => null,
    },
    boardFunding: switch (m['funding']) {
      final f? => _funding(mapValue(f)),
      null => null,
    },
  ),
);
ArkClaimRecovery _claimRecovery(Map<String, Object?> m) => ArkClaimRecovery(
  txid: m['txid'] as String,
  destination: m['destination'] as String,
  net: sats(m['net']),
  fee: sats(m['fee']),
);
ArkBoardFundingDetails _funding(Map<String, Object?> m) =>
    switch ((m.containsKey('index'), m.containsKey('scuttleToken'))) {
      (true, false) => ArkBoardFundingDetails(
        address: m['address'] as String,
        keypairIndex: m['index'] as int,
        expiryHeight: m['expiry'] as int,
      ),
      (false, true) => ArkBoardFundingDetails.scuttle(
        address: m['address'] as String,
        token: m['scuttleToken'] as String,
        expiryHeight: m['expiry'] as int,
      ),
      _ => throw const FormatException('Invalid board funding identity'),
    };

T _decode<T>(T Function() action) {
  try {
    return action();
  } on TypeError {
    throw const FormatException('Invalid Ark stored field type');
  } on ArgumentError {
    throw const FormatException('Invalid Ark stored field value');
  } on StateError {
    throw const FormatException('Invalid Ark stored field state');
  }
}

// Terminal native movements retire only VTXOs also observed natively spent:
// the inputs of a failed movement or a received Lightning payment, and the
// output of a failed Board. Bark fails a Board once a confirmed transaction
// spends its funding coins, and then marks the VTXO it promised spent: that
// VTXO never existed as money.
bool terminalMovementRetires(
  ArkMovement movement,
  String id,
  List<ArkVtxo> inventory,
) =>
    inventory.any((v) => v.id == id && v.state == ArkVtxoState.spent) &&
    ((movement.inputVtxoIds.contains(id) &&
            (movement.status == ArkMovementStatus.failed ||
                (movement.status == ArkMovementStatus.successful &&
                    movement.kind == ArkMovementKind.lightningReceive))) ||
        (movement.outputVtxoIds.contains(id) &&
            movement.kind == ArkMovementKind.board &&
            movement.status == ArkMovementStatus.failed));
