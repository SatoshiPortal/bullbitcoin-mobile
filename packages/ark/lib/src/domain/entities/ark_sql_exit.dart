/// A successful guarded lookup; absence is explicit and has no financial meaning.
sealed class ArkSqlRead<T> {
  const ArkSqlRead();
}

final class ArkSqlFound<T> extends ArkSqlRead<T> {
  final T value;
  const ArkSqlFound(this.value);
}

final class ArkSqlNotFound<T> extends ArkSqlRead<T> {
  const ArkSqlNotFound();
}

enum ArkSqlExitPhase {
  start,
  processing,
  awaitingDelta,
  claimable,
  claimInProgress,
  claimed,
  vtxoAlreadySpent,
  vtxoSwept,
  canceled,
}

enum ArkSqlExitTransactionPhase {
  verifyInputs,
  awaitingInputConfirmation,
  awaitingCpfpBroadcast,
  awaitingConfirmation,
  confirmed,
}

enum ArkSqlExitChildOrigin { wallet, mempool, block }

final class ArkSqlBlockRef {
  final int height;
  final String hash;
  const ArkSqlBlockRef({required this.height, required this.hash});
}

final class ArkSqlExitTransactionRef {
  final String parentTxid;
  final ArkSqlExitTransactionPhase phase;
  final String? childTxid;
  const ArkSqlExitTransactionRef({
    required this.parentTxid,
    required this.phase,
    this.childTxid,
  });
}

final class ArkSqlExitState {
  final String vtxoId;
  final ArkSqlExitPhase phase;

  /// Only processing references recorded in this source phase, not a full chain.
  final List<ArkSqlExitTransactionRef> transactionRefs;
  ArkSqlExitState({
    required this.vtxoId,
    required this.phase,
    required List<ArkSqlExitTransactionRef> transactionRefs,
  }) : transactionRefs = List.unmodifiable(transactionRefs);
}

/// Source-supplied consensus bytes; consensus/signature validity is UNVERIFIED.
final class ArkSqlExitChild {
  /// PARENT exit transaction ID, distinct from the VTXO ID and child TXID.
  final String parentTxid;
  final List<int> transactionBytes;
  final ArkSqlExitChildOrigin origin;
  final ArkSqlBlockRef? confirmedIn;
  ArkSqlExitChild({
    required this.parentTxid,
    required List<int> transactionBytes,
    required this.origin,
    required this.confirmedIn,
  }) : transactionBytes = List.unmodifiable(transactionBytes);
}

/// Exact separate storage components; never a Full encoding or witness proof.
final class ArkSqlVtxoComponents {
  final String vtxoId;

  /// SQL NULL is null; a stored empty BLOB remains an immutable empty list.
  final List<int>? rawBare;
  final List<int>? rawGenesis;
  ArkSqlVtxoComponents({
    required this.vtxoId,
    required List<int>? rawBare,
    required List<int>? rawGenesis,
  }) : rawBare = rawBare == null ? null : List.unmodifiable(rawBare),
       rawGenesis = rawGenesis == null ? null : List.unmodifiable(rawGenesis);
}
