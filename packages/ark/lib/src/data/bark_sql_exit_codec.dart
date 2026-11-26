import 'dart:convert';

import '../domain/entities/ark_sql_exit.dart';

final _hashPattern = RegExp(r'^[0-9a-f]{64}$');
bool isSqlTxid(String value) => _hashPattern.hasMatch(value);
bool isSqlVtxoId(String value) {
  final parts = value.split(':');
  if (parts.length != 2 || !isSqlTxid(parts.first)) return false;
  final index = int.tryParse(parts.last);
  return index != null &&
      index >= 0 &&
      index <= 0xffffffff &&
      index.toString() == parts.last;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) throw const FormatException();
  return value;
}

String _hash(Object? value) {
  if (value is! String || !isSqlTxid(value)) throw const FormatException();
  return value;
}

void _height(Object? value) {
  if (value is! int || value < 0 || value > 0xffffffff) {
    throw const FormatException();
  }
}

List<Object?> _list(Object? value) {
  if (value is! List || value.length > 256) throw const FormatException();
  return value;
}

ArkSqlBlockRef _block(Object? value) {
  final map = _object(value);
  final height = map['height'];
  _height(height);
  if (height is! int) throw const FormatException();
  return ArkSqlBlockRef(height: height, hash: _hash(map['hash']));
}

(ArkSqlExitChildOrigin, ArkSqlBlockRef?) _origin(Object? value) {
  final map = _object(value);
  switch (map['type']) {
    case 'wallet':
      if (!map.containsKey('confirmed_in')) throw const FormatException();
      return (
        ArkSqlExitChildOrigin.wallet,
        map['confirmed_in'] == null ? null : _block(map['confirmed_in']),
      );
    case 'block':
      return (ArkSqlExitChildOrigin.block, _block(map['confirmed_in']));
    case 'mempool':
      if (map.containsKey('confirmed_in')) throw const FormatException();
      return (ArkSqlExitChildOrigin.mempool, null);
    default:
      throw const FormatException();
  }
}

(ArkSqlExitChildOrigin, ArkSqlBlockRef?) decodeSqlExitOrigin(String text) =>
    _origin(jsonDecode(text));

ArkSqlExitTransactionRef _reference(Object? value) {
  final map = _object(value), status = _object(_object(value)['status']);
  String? child;
  final phase = switch (status['type']) {
    'verify-inputs' => ArkSqlExitTransactionPhase.verifyInputs,
    'awaiting-input-confirmation' =>
      ArkSqlExitTransactionPhase.awaitingInputConfirmation,
    'awaiting-cpfp-broadcast' =>
      ArkSqlExitTransactionPhase.awaitingCpfpBroadcast,
    'awaiting-confirmation' => ArkSqlExitTransactionPhase.awaitingConfirmation,
    'confirmed' => ArkSqlExitTransactionPhase.confirmed,
    _ => throw const FormatException(),
  };
  if (phase == ArkSqlExitTransactionPhase.awaitingInputConfirmation) {
    for (final txid in _list(status['txids'])) {
      _hash(txid);
    }
  }
  if (phase == ArkSqlExitTransactionPhase.awaitingConfirmation ||
      phase == ArkSqlExitTransactionPhase.confirmed) {
    child = _hash(status['child_txid']);
    _origin(status['origin']);
  }
  if (phase == ArkSqlExitTransactionPhase.confirmed) _block(status['block']);
  return ArkSqlExitTransactionRef(
    parentTxid: _hash(map['txid']),
    phase: phase,
    childTxid: child,
  );
}

ArkSqlExitState decodeSqlExitState(String id, String text) {
  final map = _object(jsonDecode(text));
  _height(map['tip_height']);
  final phase = switch (map['type']) {
    'start' => ArkSqlExitPhase.start,
    'processing' => ArkSqlExitPhase.processing,
    'awaiting-delta' => ArkSqlExitPhase.awaitingDelta,
    'claimable' => ArkSqlExitPhase.claimable,
    'claim-in-progress' => ArkSqlExitPhase.claimInProgress,
    'claimed' => ArkSqlExitPhase.claimed,
    'vtxo-already-spent' => ArkSqlExitPhase.vtxoAlreadySpent,
    'vtxo-swept' => ArkSqlExitPhase.vtxoSwept,
    'canceled' => ArkSqlExitPhase.canceled,
    _ => throw const FormatException(),
  };
  switch (phase) {
    case ArkSqlExitPhase.awaitingDelta:
      _block(map['confirmed_block']);
      _height(map['claimable_height']);
    case ArkSqlExitPhase.claimable:
      _block(map['claimable_since']);
      if (!map.containsKey('last_scanned_block')) throw const FormatException();
      if (map['last_scanned_block'] != null) _block(map['last_scanned_block']);
    case ArkSqlExitPhase.claimInProgress:
      _block(map['claimable_since']);
      _hash(map['claim_txid']);
    case ArkSqlExitPhase.claimed:
      _hash(map['txid']);
      _block(map['block']);
    case ArkSqlExitPhase.vtxoSwept:
      for (final input in _list(map['spent_inputs'])) {
        if (input is! String || !isSqlVtxoId(input)) {
          throw const FormatException();
        }
      }
    case ArkSqlExitPhase.start ||
        ArkSqlExitPhase.processing ||
        ArkSqlExitPhase.vtxoAlreadySpent ||
        ArkSqlExitPhase.canceled:
      break;
  }
  return ArkSqlExitState(
    vtxoId: id,
    phase: phase,
    transactionRefs: phase == ArkSqlExitPhase.processing
        ? _list(map['transactions']).map(_reference).toList()
        : const [],
  );
}
