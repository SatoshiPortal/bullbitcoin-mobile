import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autosweep/application/autosweep_fee_policy.dart';
import 'package:bb_mobile/features/autosweep/application/ports/autosweep_wallet_port.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class RunAutoSweepUsecase {
  static const int _dustThresholdSat = 100;

  final AutosweepWalletPort _wallets;
  final BroadcastLiquidTransactionUsecase _broadcastLiquid;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoin;
  final GetNetworkFeesUsecase _getNetworkFees;
  final LabelsFacade _labelsFacade;
  final AutosweepFeePolicy _feePolicy;

  final Set<String> _inFlightWalletIds = {};

  RunAutoSweepUsecase({
    required this._wallets,
    required this._broadcastLiquid,
    required this._broadcastBitcoin,
    required this._getNetworkFees,
    required this._labelsFacade,
    required this._feePolicy,
  });

  Future<String?> execute(Wallet syncedWallet) async {
    if (!syncedWallet.autoSweepEnabled) return null;
    if (syncedWallet.balanceSat <= BigInt.from(_dustThresholdSat)) return null;
    if (!_inFlightWalletIds.add(syncedWallet.id)) return null;

    try {
      final txid = syncedWallet.isLiquid
          ? await _sweepLiquid(syncedWallet)
          : await _sweepBitcoin(syncedWallet);
      if (txid == null) return null;

      await _storeSweepLabel(
        txid: txid,
        label: 'Autosweep from ${syncedWallet.label ?? syncedWallet.id}',
        origin: syncedWallet.id,
      );
      return txid;
    } finally {
      _inFlightWalletIds.remove(syncedWallet.id);
    }
  }

  Future<String?> _sweepLiquid(Wallet sourceWallet) async {
    final defaultLiquid = await _defaultWallet(
      sourceWallet: sourceWallet,
      onlyLiquid: true,
    );
    if (defaultLiquid == null) return null;
    if (defaultLiquid.id == sourceWallet.id) return null;

    final destinationAddress = await _wallets.getCurrentReceiveAddress(
      walletId: defaultLiquid.id,
    );

    final pset = await _wallets.buildLiquidDrainPset(
      walletId: sourceWallet.id,
      address: destinationAddress,
      networkFee: const NetworkFee.relative(0.1),
    );

    final signedPset = await _wallets.signLiquidPset(
      pset: pset,
      walletId: sourceWallet.id,
    );

    return _broadcastLiquid.execute(
      signedPset,
      isTestnet: sourceWallet.isTestnet,
    );
  }

  Future<String?> _sweepBitcoin(Wallet sourceWallet) async {
    final defaultBitcoin = await _defaultWallet(
      sourceWallet: sourceWallet,
      onlyBitcoin: true,
    );
    if (defaultBitcoin == null) return null;
    if (defaultBitcoin.id == sourceWallet.id) return null;

    final destinationAddress = await _wallets.getCurrentReceiveAddress(
      walletId: defaultBitcoin.id,
    );

    final fees = await _getNetworkFees.execute(isLiquid: false);
    final psbt = await _wallets.buildBitcoinDrainPsbt(
      walletId: sourceWallet.id,
      address: destinationAddress,
      networkFee: fees.economic,
    );

    final feeSat = await _wallets.getBitcoinFeeSat(psbt: psbt);
    if (!_feePolicy.allowsBitcoinSweep(
      feeSat: feeSat,
      walletBalanceSat: sourceWallet.balanceSat,
    )) {
      log.warning('Bitcoin autosweep skipped because fee exceeds policy');
      return null;
    }

    final signedPsbt = await _wallets.signBitcoinPsbt(
      psbt: psbt,
      walletId: sourceWallet.id,
    );
    return _broadcastBitcoin.execute(signedPsbt, isPsbt: true);
  }

  Future<Wallet?> _defaultWallet({
    required Wallet sourceWallet,
    bool onlyBitcoin = false,
    bool onlyLiquid = false,
  }) async {
    return _wallets.getDefaultWallet(
      sourceWallet: sourceWallet,
      onlyBitcoin: onlyBitcoin,
      onlyLiquid: onlyLiquid,
    );
  }

  Future<void> _storeSweepLabel({
    required String txid,
    required String label,
    required String origin,
  }) async {
    try {
      await _labelsFacade.store(
        NewLabel.tx(transactionId: txid, label: label, origin: origin),
      );
    } catch (e) {
      log.warning('Autosweep label transfer failed', error: e);
    }
  }
}
