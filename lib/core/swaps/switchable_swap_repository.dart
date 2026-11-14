import 'dart:async';

import 'package:swaps/swaps.dart';

/// One network's engine: the Boltz connection and the repository on it.
typedef SwapEngineParts = ({
  BoltzSwapRepository repository,
  BoltzDatasource datasource,
});

/// The [SwapRepository] everything in the app holds. It forwards to the
/// engine for the current network and can [replace] it, so a network or
/// server switch reaches every holder without re-registering them.
class SwitchableSwapRepository implements SwapRepository {
  SwapEngineParts _parts;
  final StreamController<Swap> _updates = StreamController<Swap>.broadcast();
  StreamSubscription<Swap>? _forwarding;

  SwitchableSwapRepository(this._parts) {
    _forward();
  }

  BoltzSwapRepository get current => _parts.repository;

  /// Points every call at [next] and stops the previous engine's live
  /// traffic. Calls already running on the previous engine finish there.
  Future<void> replace(SwapEngineParts next) async {
    final previous = _parts;
    _parts = next;
    await _forwarding?.cancel();
    _forward();
    previous.datasource.dispose();
  }

  void _forward() {
    _forwarding = _parts.repository.updates.listen(
      _updates.add,
      onError: _updates.addError,
    );
  }

  @override
  bool get isTestnet => current.isTestnet;

  @override
  Stream<Swap> get updates => _updates.stream;

  @override
  Future<Swap> get(String swapId) => current.get(swapId);

  @override
  Stream<Swap> watch(String swapId) => current.watch(swapId);

  @override
  Future<List<Swap>> all({String? walletId}) => current.all(walletId: walletId);

  @override
  Future<Swap?> byTxId(String txId) => current.byTxId(txId);

  @override
  Future<List<Swap>> ongoing({String? walletId}) =>
      current.ongoing(walletId: walletId);

  @override
  Future<SwapLimits> limits(SwapType type) => current.limits(type);

  @override
  Future<(SwapLimits, SwapFees)> limitsAndFees(SwapType type) =>
      current.limitsAndFees(type);

  @override
  Future<void> markLockupBroadcast({
    required String swapId,
    required String txid,
    int? lockupFeeSat,
  }) => current.markLockupBroadcast(
    swapId: swapId,
    txid: txid,
    lockupFeeSat: lockupFeeSat,
  );

  @override
  Future<Swap> recordPendingLockup({
    required String swapId,
    required String signedTx,
  }) => current.recordPendingLockup(swapId: swapId, signedTx: signedTx);

  @override
  Future<void> dropPendingLockup(String swapId) =>
      current.dropPendingLockup(swapId);

  @override
  Future<Swap> resolvePendingLockup(Swap swap) =>
      current.resolvePendingLockup(swap);

  @override
  Future<LnReceiveSwap> createLightningReceive({
    required String walletId,
    required int amountSat,
    required bool toLiquid,
    String? description,
  }) => current.createLightningReceive(
    walletId: walletId,
    amountSat: amountSat,
    toLiquid: toLiquid,
    description: description,
  );

  @override
  Future<LnSendSwap?> pendingLightningSend({
    required String invoice,
    required String walletId,
    required bool fromLiquid,
  }) => current.pendingLightningSend(
    invoice: invoice,
    walletId: walletId,
    fromLiquid: fromLiquid,
  );

  @override
  Future<LnSendSwap> createLightningSend({
    required String walletId,
    required String invoice,
    required bool fromLiquid,
  }) => current.createLightningSend(
    walletId: walletId,
    invoice: invoice,
    fromLiquid: fromLiquid,
  );

  @override
  Future<ChainSwap> createChain({
    required String sendWalletId,
    required int amountSat,
    required bool fromLiquid,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) => current.createChain(
    sendWalletId: sendWalletId,
    amountSat: amountSat,
    fromLiquid: fromLiquid,
    receiveWalletId: receiveWalletId,
    externalRecipientAddress: externalRecipientAddress,
  );

  @override
  Future<String> claim(Swap swap, {bool scriptPathOnly = false}) =>
      current.claim(swap, scriptPathOnly: scriptPathOnly);

  @override
  Future<String> refund(Swap swap, {bool scriptPathOnly = false}) =>
      current.refund(swap, scriptPathOnly: scriptPathOnly);

  @override
  Future<String> resolveScriptPath(Swap swap) =>
      current.resolveScriptPath(swap);

  @override
  Future<void> coopSign(Swap swap) => current.coopSign(swap);

  @override
  Future<Swap> reconcileLockupTxid(Swap swap) =>
      current.reconcileLockupTxid(swap);

  @override
  void listen(List<String> swapIds) => current.listen(swapIds);

  @override
  Future<void> reconcile(List<String> swapIds) => current.reconcile(swapIds);

  @override
  Future<void> verifyCompletions() => current.verifyCompletions();

  @override
  Future<List<RestoredSwap>> restore() => current.restore();

  @override
  Future<Swap> rescue(RestoredSwap restored, {required String walletId}) =>
      current.rescue(restored, walletId: walletId);
}
