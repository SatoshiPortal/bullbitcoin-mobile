import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';

/// One network's engine: its store and its Boltz provider.
typedef SwapEngineParts = ({SwapStore store, BoltzSwapRepository boltz});

/// The swap engine everything in the app holds. It forwards to the engine
/// for the current network and can [replace] it, so a network or server
/// switch reaches every holder without re-registering them.
class SwitchableSwapEngine implements SwapStore, SwapResolver, BoltzSwaps {
  SwapEngineParts _parts;
  final StreamController<Swap> _updates = StreamController<Swap>.broadcast();
  StreamSubscription<Swap>? _forwarding;

  SwitchableSwapEngine(this._parts) {
    _forward();
  }

  SwapStore get _store => _parts.store;
  BoltzSwapRepository get _boltz => _parts.boltz;

  /// Points every call at [next] and closes the previous provider's
  /// connection. Calls already running on the previous engine finish there.
  Future<void> replace(SwapEngineParts next) async {
    final previous = _parts;
    _parts = next;
    await _forwarding?.cancel();
    _forward();
    previous.boltz.dispose();
  }

  void _forward() {
    _forwarding = _boltz.updates.listen(
      _updates.add,
      onError: _updates.addError,
    );
  }

  // SwapStore

  @override
  Future<Result<Swap, SwapsFailure>> get(String swapId) => _store.get(swapId);

  @override
  Stream<Swap> watch(String swapId) => _store.watch(swapId);

  @override
  Future<Result<List<Swap>, SwapsFailure>> all({String? walletId}) =>
      _store.all(walletId: walletId);

  @override
  Future<Result<Swap?, SwapsFailure>> byTxId(String txId) =>
      _store.byTxId(txId);

  @override
  Future<Result<List<Swap>, SwapsFailure>> ongoing({String? walletId}) =>
      _store.ongoing(walletId: walletId);

  // SwapResolver

  @override
  bool get isTestnet => _boltz.isTestnet;

  @override
  Stream<Swap> get updates => _updates.stream;

  @override
  Future<Result<Swap, SwapsFailure>> resolve(Swap swap) => _boltz.resolve(swap);

  @override
  Future<Result<Swap, SwapsFailure>> resolveScriptPath(Swap swap) =>
      _boltz.resolveScriptPath(swap);

  @override
  void listen(List<String> swapIds) => _boltz.listen(swapIds);

  @override
  Future<Result<void, SwapsFailure>> reconcile(List<String> swapIds) =>
      _boltz.reconcile(swapIds);

  @override
  Future<Result<void, SwapsFailure>> verifyCompletions() =>
      _boltz.verifyCompletions();

  @override
  Future<Result<Swap, SwapsFailure>> recordPendingLockup({
    required String swapId,
    required String signedTx,
  }) => _boltz.recordPendingLockup(swapId: swapId, signedTx: signedTx);

  @override
  Future<Result<void, SwapsFailure>> dropPendingLockup(String swapId) =>
      _boltz.dropPendingLockup(swapId);

  @override
  Future<Result<Swap, SwapsFailure>> recordLockup({
    required String swapId,
    required String txid,
    int? lockupFeeSat,
  }) => _boltz.recordLockup(
    swapId: swapId,
    txid: txid,
    lockupFeeSat: lockupFeeSat,
  );

  @override
  Future<Result<List<RestoredSwap>, SwapsFailure>> restore() =>
      _boltz.restore();

  @override
  Future<Result<Swap, SwapsFailure>> rescue(
    RestoredSwap restored, {
    required String walletId,
  }) => _boltz.rescue(restored, walletId: walletId);

  // BoltzSwaps

  @override
  Future<Result<(SwapLimits, SwapFees), SwapsFailure>> limitsAndFees(
    SwapType type,
  ) => _boltz.limitsAndFees(type);

  @override
  Future<Result<LnSendSwap, SwapsFailure>> createBitcoinToLightningSwap({
    required String walletId,
    required String invoice,
  }) =>
      _boltz.createBitcoinToLightningSwap(walletId: walletId, invoice: invoice);

  @override
  Future<Result<LnSendSwap, SwapsFailure>> createLiquidToLightningSwap({
    required String walletId,
    required String invoice,
  }) =>
      _boltz.createLiquidToLightningSwap(walletId: walletId, invoice: invoice);

  @override
  Future<Result<LnReceiveSwap, SwapsFailure>> createLightningToBitcoinSwap({
    required String walletId,
    required int amountSat,
    String? description,
  }) => _boltz.createLightningToBitcoinSwap(
    walletId: walletId,
    amountSat: amountSat,
    description: description,
  );

  @override
  Future<Result<LnReceiveSwap, SwapsFailure>> createLightningToLiquidSwap({
    required String walletId,
    required int amountSat,
    String? description,
  }) => _boltz.createLightningToLiquidSwap(
    walletId: walletId,
    amountSat: amountSat,
    description: description,
  );

  @override
  Future<Result<ChainSwap, SwapsFailure>> createBitcoinToLiquidSwap({
    required String sendWalletId,
    required int amountSat,
    required ChainSwapDestination destination,
  }) => _boltz.createBitcoinToLiquidSwap(
    sendWalletId: sendWalletId,
    amountSat: amountSat,
    destination: destination,
  );

  @override
  Future<Result<ChainSwap, SwapsFailure>> createLiquidToBitcoinSwap({
    required String sendWalletId,
    required int amountSat,
    required ChainSwapDestination destination,
  }) => _boltz.createLiquidToBitcoinSwap(
    sendWalletId: sendWalletId,
    amountSat: amountSat,
    destination: destination,
  );

  @override
  Future<Result<SwapMasterKeyInfo?, SwapsFailure>> masterKeyInfo() =>
      _boltz.masterKeyInfo();

  @override
  Future<Result<String?, SwapsFailure>> masterKeyMnemonic({
    required String walletFingerprint,
  }) => _boltz.masterKeyMnemonic(walletFingerprint: walletFingerprint);

  @override
  Future<Result<void, SwapsFailure>> deleteMasterKey() =>
      _boltz.deleteMasterKey();
}
