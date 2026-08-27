import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_failure.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_fee_policy.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_result.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

/// Registered as a lazySingleton on purpose: the in-flight wallet id set
/// deduplicates sweeps triggered by concurrent wallet syncs, which only
/// works when every caller shares the same instance.
class RunAutoSweepUsecase {
  static const int _dustThresholdSat = 100;

  final WalletRepository _walletRepository;
  final WalletAddressRepository _walletAddressRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final BroadcastLiquidTransactionUsecase _broadcastLiquid;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoin;
  final GetNetworkFeesUsecase _getNetworkFees;
  final LabelsFacade _labelsFacade;
  final AutosweepFeePolicy _feePolicy;
  final Future<Result<List<WalletPreferences>, WalletPreferencesFailure>>
  Function()
  _getPreferences;

  final Set<String> _inFlightWalletIds = {};

  RunAutoSweepUsecase(
    this._walletRepository,
    this._walletAddressRepository,
    this._liquidWalletRepository,
    this._bitcoinWalletRepository,
    this._broadcastLiquid,
    this._broadcastBitcoin,
    this._getNetworkFees,
    this._labelsFacade,
    this._feePolicy,
    this._getPreferences,
  );

  Future<AutosweepResult> execute(Wallet syncedWallet) async {
    final preferences = await _getPreferences();
    final enabled = switch (preferences) {
      Ok(:final value) =>
        value
                .where((item) => item.walletRef == syncedWallet.id)
                .firstOrNull
                ?.autoSweepEnabled ??
            false,
      Err() => false,
    };
    if (!enabled) {
      return const AutosweepSkipped(AutosweepSkipReason.disabled);
    }
    if (syncedWallet.balanceSat <= BigInt.from(_dustThresholdSat)) {
      return const AutosweepSkipped(AutosweepSkipReason.dust);
    }
    if (!_inFlightWalletIds.add(syncedWallet.id)) {
      return const AutosweepSkipped(AutosweepSkipReason.inFlight);
    }

    try {
      final result = syncedWallet.isLiquid
          ? await _sweepLiquid(syncedWallet)
          : await _sweepBitcoin(syncedWallet);
      if (result is AutosweepSwept) {
        final featureLabel = _reservedFeatureLabel(syncedWallet);
        await _storeSweepLabel(
          txid: result.txid,
          // A swept reserved Get Paid wallet is labelled with the product's
          // display name; any other wallet (a user manually enabling auto-sweep
          // on a normal wallet) keeps the original free-form label.
          label:
              featureLabel?.label ??
              'Autosweep from ${syncedWallet.label ?? syncedWallet.id}',
          origin: syncedWallet.id,
        );
      }
      return result;
    } on Exception catch (error, trace) {
      log.warning('Autosweep failed', error: error.runtimeType, trace: trace);
      return const AutosweepFailed(AutosweepOperationFailure());
    } finally {
      _inFlightWalletIds.remove(syncedWallet.id);
    }
  }

  Future<AutosweepResult> _sweepLiquid(Wallet sourceWallet) async {
    final defaultLiquid = await _defaultWallet(
      sourceWallet: sourceWallet,
      onlyLiquid: true,
    );
    if (defaultLiquid == null) {
      return const AutosweepSkipped(AutosweepSkipReason.noDefaultWallet);
    }
    if (defaultLiquid.id == sourceWallet.id) {
      return const AutosweepSkipped(AutosweepSkipReason.selfSweep);
    }

    final destinationAddress =
        (await _walletAddressRepository.getLastRevealedReceiveAddress(
          walletId: defaultLiquid.id,
        )).address;

    final pset = await _liquidWalletRepository.buildPset(
      walletId: sourceWallet.id,
      address: destinationAddress,
      feeRate: NetworkFee.relativeFromSatPerVbyte(0.1),
      drain: true,
    );

    final signedPset = await _liquidWalletRepository.signPset(
      pset: pset,
      walletId: sourceWallet.id,
    );

    final txid = await _broadcastLiquid.execute(
      signedPset,
      isTestnet: sourceWallet.isTestnet,
    );
    return AutosweepSwept(txid);
  }

  Future<AutosweepResult> _sweepBitcoin(Wallet sourceWallet) async {
    final defaultBitcoin = await _defaultWallet(
      sourceWallet: sourceWallet,
      onlyBitcoin: true,
    );
    if (defaultBitcoin == null) {
      return const AutosweepSkipped(AutosweepSkipReason.noDefaultWallet);
    }
    if (defaultBitcoin.id == sourceWallet.id) {
      return const AutosweepSkipped(AutosweepSkipReason.selfSweep);
    }

    final destinationAddress =
        (await _walletAddressRepository.getLastRevealedReceiveAddress(
          walletId: defaultBitcoin.id,
        )).address;

    final fees = await _getNetworkFees.execute(isLiquid: false);
    final psbt = await _bitcoinWalletRepository.buildPsbt(
      walletId: sourceWallet.id,
      address: destinationAddress,
      networkFee: fees.economic,
      drain: true,
    );

    final feeSat = await _bitcoinWalletRepository.getTxFeeAmount(psbt: psbt);
    if (!_feePolicy.allowsBitcoinSweep(
      feeSat: feeSat,
      walletBalanceSat: sourceWallet.balanceSat,
    )) {
      log.warning('Bitcoin autosweep skipped because fee exceeds policy');
      return const AutosweepSkipped(AutosweepSkipReason.feePolicy);
    }

    final signedPsbt = await _bitcoinWalletRepository.signPsbt(
      psbt,
      walletId: sourceWallet.id,
    );
    final txid = await _broadcastBitcoin.execute(signedPsbt, isPsbt: true);
    return AutosweepSwept(txid);
  }

  Future<Wallet?> _defaultWallet({
    required Wallet sourceWallet,
    bool onlyBitcoin = false,
    bool onlyLiquid = false,
  }) async {
    final wallets = await _walletRepository.getWallets(
      environment: sourceWallet.isTestnet
          ? Environment.testnet
          : Environment.mainnet,
      onlyDefaults: true,
      onlyBitcoin: onlyBitcoin,
      onlyLiquid: onlyLiquid,
    );
    return wallets.firstOrNull;
  }

  // Maps a reserved Get Paid product wallet to the system label whose display
  // name is the product's name. The matched labels mirror the wallet labels set
  // at creation time (the Prepare*WalletUsecase specs and BtcpayWalletConstants)
  // — kept as literals here so core autosweep takes no feature dependency and no
  // server call. Only the Liquid wallets actually reach here (BTCPay's Bitcoin
  // wallet is created with auto-sweep off), but both BTCPay labels are mapped
  // defensively. A non-reserved wallet returns null (free-form fallback).
  LabelSystem? _reservedFeatureLabel(Wallet wallet) {
    return switch (wallet.label) {
      'Lightning Address Liquid' => LabelSystem.lightningAddress,
      'Payment Page Liquid' => LabelSystem.paymentPage,
      'POS Liquid' => LabelSystem.pointOfSale,
      'BTCPay Liquid' || 'BTCPay Bitcoin' => LabelSystem.btcpay,
      _ => null,
    };
  }

  Future<void> _storeSweepLabel({
    required String txid,
    required String label,
    required String origin,
  }) async {
    final result = await _labelsFacade.store(
      NewLabel.tx(transactionId: txid, label: label, origin: origin),
    );
    if (result case Err(:final failure)) {
      log.warning(
        'Autosweep label transfer failed',
        error: failure.runtimeType,
      );
    }
  }
}
