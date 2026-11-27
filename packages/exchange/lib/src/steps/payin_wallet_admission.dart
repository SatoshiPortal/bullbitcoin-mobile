import 'package:primitives/primitives.dart' show Network;

/// Read-only, process-local identity of a selected wallet. The host supplies
/// a synchronous witness that verifies the durable incarnation at use.
final class PayinWalletWitness {
  final String walletId;
  final Network network;
  final int generation;
  final Object? Function() _currentReceipt;

  const PayinWalletWitness({
    required this.walletId,
    required this.network,
    required this.generation,
    required this._currentReceipt,
  });

  bool get isCurrent => _currentReceipt() != null;
}

/// One flow's selection lifetime. Never serialize an attempt or use it to
/// resume a journaled operation. Reconciliation does not require a witness.
final class PayinWalletAttempt {
  final PayinWalletWitness _witness;
  var _retired = false;

  PayinWalletAttempt(this._witness);

  bool get isCurrent => !_retired && _witness.isCurrent;

  void retire() => _retired = true;

  bool matches(String id, Network network, int generation) =>
      _witness.walletId == id &&
      _witness.network == network &&
      _witness.generation == generation &&
      isCurrent;

  /// Call synchronously at the owner's actual effect boundary, after all
  /// prerequisite waits. Never replace a result after dispatch: successful
  /// and uncertain submissions still belong to this attempt.
  Future<T> submit<T>({
    required String id,
    required Network network,
    required int generation,
    required T refused,
    required Future<T> Function() dispatch,
  }) => matches(id, network, generation) ? dispatch() : Future.value(refused);

  /// Read-only work may finish after revocation; its result must not escape.
  Future<T?> read<T>({
    required String id,
    required Network network,
    required int generation,
    required Future<T> Function() load,
  }) async {
    if (!matches(id, network, generation)) return null;
    final receipt = _witness._currentReceipt();
    if (receipt == null) return null;
    final result = await load();
    return !_retired && identical(receipt, _witness._currentReceipt())
        ? result
        : null;
  }
}
