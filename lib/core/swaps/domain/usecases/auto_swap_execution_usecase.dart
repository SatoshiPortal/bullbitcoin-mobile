import 'package:bb_mobile/core/errors/autoswap_errors.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/ports/blockchain_port.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/liquid_tx_output.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_build_tx_exceptions.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class AutoSwapExecutionUsecase {
  final BoltzSwapRepository _repository;
  final WalletRepository _walletRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final WalletUtxoRepository _walletUtxoRepository;
  final WalletAddressRepository _walletAddressRepository;
  final BlockchainPort _blockchainPort;
  final WalletTransactionRepository _walletTxRepository;
  final LabelsFacade _labelsFacade;

  AutoSwapExecutionUsecase({
    required this._repository,
    required this._walletRepository,
    required this._liquidWalletRepository,
    required this._walletUtxoRepository,
    required this._walletAddressRepository,
    required this._blockchainPort,
    required this._walletTxRepository,
    required this._labelsFacade,
  });

  Future<Swap> execute({required bool feeBlock}) async {
    final swapRepository = _repository;
    final autoSwapSettings = await swapRepository.getAutoSwapParams();
    // check if recipient wallet id is set

    if (!autoSwapSettings.enabled || autoSwapSettings.showWarning) {
      throw AutoSwapDisabledException(
        'Auto swap is disabled/warning not disabled yet.',
      );
    }
    final wallets = await _walletRepository.getWallets(
      environment: Environment.mainnet,
    );
    final defaultBitcoinWallet = wallets
        .where((w) => w.isDefault && !w.isLiquid)
        .firstOrNull;
    final defaultLiquidWallet = wallets
        .where((w) => w.isDefault && w.isLiquid)
        .firstOrNull;

    if (defaultLiquidWallet == null || defaultBitcoinWallet == null) {
      throw Exception('No default wallets found');
    }

    if (autoSwapSettings.recipientWalletId == null) {
      final updatedSwapSettings = autoSwapSettings.copyWith(
        recipientWalletId: defaultBitcoinWallet.id,
      );
      await swapRepository.updateAutoSwapParams(updatedSwapSettings);
    }

    final sendBitcoinWallet = autoSwapSettings.recipientWalletId != null
        ? wallets
              .where((w) => w.id == autoSwapSettings.recipientWalletId)
              .firstOrNull
        : defaultBitcoinWallet;

    if (sendBitcoinWallet == null) {
      // if user deleted the bitcoin wallet, this could be null
      // TODO: when a set autoswap wallet is deleted, we should prompt the user to update the autoswap settings
      throw Exception(
        'Send bitcoin wallet not found. Check autoswap settings.',
      );
    }
    log.fine('Found default wallet - Liquid: ${defaultLiquidWallet.id}');

    final walletBalance = defaultLiquidWallet.balanceSat.toInt();

    log.fine('Checking balance threshold - Current: $walletBalance sats');
    if (!autoSwapSettings.passedRequiredBalance(walletBalance)) {
      throw BalanceThresholdException(
        currentBalance: walletBalance,
        requiredBalance: autoSwapSettings.triggerBalanceSats,
      );
    }

    log.fine('Balance threshold exceeded, checking swap limits...');
    final (swapLimits, swapFees) = await swapRepository.getSwapLimitsAndFees(
      SwapType.liquidToBitcoin,
    );

    if (walletBalance < swapLimits.min || walletBalance > swapLimits.max) {
      throw Exception(
        'Balance outside swap limits (min: ${swapLimits.min}, max: ${swapLimits.max})',
      );
    }

    if (feeBlock) {
      final totalFeePercent = swapFees.totalFeeAsPercentOfAmount(
        autoSwapSettings.swapAmount(walletBalance),
      );

      if (totalFeePercent > autoSwapSettings.feeThresholdPercent) {
        throw FeeBlockException(
          currentFeePercent: totalFeePercent,
          thresholdPercent: autoSwapSettings.feeThresholdPercent,
        );
      }
    }

    log.fine('Balance within swap limits, preparing swap...');

    final btcElectrumUrl = defaultBitcoinWallet.isTestnet
        ? ApiServiceConstants.publicElectrumTestUrl
        : ApiServiceConstants.bbElectrumUrl;

    final lbtcElectrumUrl = defaultLiquidWallet.isTestnet
        ? ApiServiceConstants.publicliquidElectrumTestUrlPath
        : ApiServiceConstants.bbLiquidElectrumUrlPath;

    log.fine(
      'Creating swap with amount: ${autoSwapSettings.swapAmount(walletBalance)} sats',
    );
    final swap = await swapRepository.createLiquidToBitcoinSwap(
      sendWalletId: defaultLiquidWallet.id,
      amountSat: autoSwapSettings.swapAmount(walletBalance),
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
      receiveWalletId: sendBitcoinWallet.id,
    );

    log.fine('Building PSET...');
    // Built via buildCustomTx (an explicit UTXO list), not buildPset (LWK's
    // own coin selection, which is known to add every L-BTC UTXO regardless
    // of amount — see PrepareLiquidSendUsecase) — this is a background,
    // unattended payment, so a frozen UTXO (e.g. a consolidation decoy,
    // which must never be re-spent) must never be able to slip in here
    // either, same as an ordinary user-initiated send.
    final confirmed = await _liquidWalletRepository.getConfirmedLbtcOutpoints(
      walletId: defaultLiquidWallet.id,
    );
    final frozen = (await _walletUtxoRepository.getAllFrozenOutpoints())
        .toSet();
    final usable = confirmed.where((o) => !frozen.contains(o)).toList();

    if (usable.isEmpty) {
      throw NoSpendableUtxoException(
        'Wallet ${defaultLiquidWallet.id} has no spendable (confirmed, '
        'unfrozen) L-BTC UTXOs',
      );
    }
    if (_liquidWalletRepository.exceedsLiquidInputLimit(usable.length)) {
      throw LiquidInputLimitExceededException(
        'Wallet ${defaultLiquidWallet.id} exceeds the Liquid confidential-tx '
        'input limit',
      );
    }

    final changeAddress = await _walletAddressRepository
        .generateNewReceiveAddress(walletId: defaultLiquidWallet.id);
    final pset = await _liquidWalletRepository.buildCustomTx(
      walletId: defaultLiquidWallet.id,
      utxos: usable,
      outputs: [
        LiquidTxOutput(
          address: swap.paymentAddress,
          satoshi: swap.paymentAmount,
        ),
      ],
      drainToAddress: changeAddress.address,
      // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
      feeRate: const RelativeFee(25),
    );

    log.fine('Getting absolute fees from PSET...');
    final (_, absoluteFees) = await _liquidWalletRepository
        .getPsetSizeAndAbsoluteFees(pset: pset);

    log.fine('Signing PSET...');
    final signedPset = await _liquidWalletRepository.signPset(
      walletId: defaultLiquidWallet.id,
      pset: pset,
    );

    log.fine('Broadcasting transaction...');
    final txid = await _blockchainPort.broadcastLiquidTransaction(
      signedPset: signedPset,
      isTestnet: defaultLiquidWallet.isTestnet,
    );

    await swapRepository.updatePaidSendSwap(
      swapId: swap.id,
      txid: txid,
      absoluteFees: absoluteFees,
    );
    // Reset blockTillNextExecution after successful swap
    await swapRepository.updateAutoSwapParams(
      autoSwapSettings.copyWith(blockTillNextExecution: false),
    );
    log.fine('Swap executed successfully!');
    // sometimes sync fails and label is not set
    final txLabel = NewLabel.tx(
      transactionId: txid,
      origin: defaultLiquidWallet.id,
      label: 'Auto-Swap',
    );
    await _labelsFacade.store(txLabel);

    // sync at the end to ensure label is set
    await _walletTxRepository.getWalletTransaction(
      txid,
      walletId: defaultLiquidWallet.id,
      sync: true,
    );
    return swap;
  }
}
