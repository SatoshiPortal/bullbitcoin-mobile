import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/ports/blockchain_port.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/ensure_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/swap_provider_mode.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

/// Creates a [BoltzSwapRepository] for a given validated server URL.
///
/// Injected so tests can substitute a mock; in production it builds a real
/// [BoltzDatasource] + [BoltzSwapRepository] pair.
typedef BoltzSwapRepositoryFactory =
    BoltzSwapRepository Function(String strippedUrl);

/// Executes one autoswap cycle: reads settings, checks the Liquid balance,
/// picks the provider (Exchange or Boltz) and moves funds without user
/// interaction.
///
/// Exchange is the primary provider. Boltz is used only when a Boltz server
/// URL is configured in the autoswap settings — meaning the user already
/// switched providers.
class ExecuteAutoswapUsecase {
  final GetAutoSwapSettingsUsecase _getSettings;
  final WalletRepository _walletRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final BlockchainPort _blockchainPort;
  final GetReceiveAddressUsecase _getReceiveAddress;
  final SwapFacade _swapFacade;
  final BoltzSwapRepositoryFactory _boltzRepositoryFactory;
  final EnsureSwapMasterKeyUsecase _ensureSwapMasterKey;
  final LabelsFacade _labelsFacade;

  ExecuteAutoswapUsecase({
    required this._getSettings,
    required this._walletRepository,
    required this._liquidWalletRepository,
    required this._blockchainPort,
    required this._getReceiveAddress,
    required this._swapFacade,
    required this._boltzRepositoryFactory,
    required this._ensureSwapMasterKey,
    required this._labelsFacade,
  });

  /// Runs one autoswap check-and-execute cycle.
  ///
  /// Returns the swap identifier (Exchange order local ID or Boltz swap ID)
  /// on success, or a typed [AutoswapFailure] describing why it did not run.
  Future<Result<String, AutoswapFailure>> execute() async {
    final settings = await _getSettings.execute();

    if (!settings.enabled || settings.showWarning) {
      return const Err(AutoswapDisabledFailure());
    }
    if (settings.violation != null) {
      return Err(AutoswapInvalidSettingsFailure(settings.violation!));
    }

    final wallets = await _walletRepository.getWallets(
      environment: Environment.mainnet,
    );
    final liquidWallet = wallets
        .where((w) => w.isDefault && w.isLiquid)
        .firstOrNull;
    final bitcoinWallet = wallets
        .where((w) => w.isDefault && !w.isLiquid)
        .firstOrNull;

    if (liquidWallet == null || bitcoinWallet == null) {
      return const Err(AutoswapNoDefaultWalletFailure());
    }

    final balanceSat = liquidWallet.balanceSat.toInt();
    if (!settings.passedRequiredBalance(balanceSat)) {
      return Err(
        AutoswapInsufficientBalanceFailure(
          currentBalanceSats: balanceSat,
          requiredThresholdSats: settings.triggerBalanceSats,
        ),
      );
    }

    final amountSat = settings.swapAmount(balanceSat);
    final recipientWalletId = settings.recipientWalletId ?? bitcoinWallet.id;

    return switch (settings.providerMode) {
      SwapProviderMode.exchange => _executeExchange(
        settings: settings,
        liquidWallet: liquidWallet,
        bitcoinWallet: bitcoinWallet,
        amountSat: amountSat,
        recipientWalletId: recipientWalletId,
      ),
      SwapProviderMode.boltz => _executeBoltz(
        settings: settings,
        liquidWallet: liquidWallet,
        bitcoinWallet: bitcoinWallet,
        amountSat: amountSat,
        recipientWalletId: recipientWalletId,
      ),
    };
  }

  // ── Exchange path ──────────────────────────────────────────────────────

  Future<Result<String, AutoswapFailure>> _executeExchange({
    required AutoSwap settings,
    required Wallet liquidWallet,
    required Wallet bitcoinWallet,
    required int amountSat,
    required String recipientWalletId,
  }) async {
    // 1. Quote
    final quoteResult = await _swapFacade.getQuote(
      environment: OrderSwapEnvironment.mainnet,
      amountSat: BigInt.from(amountSat),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
    );
    if (quoteResult case Err(:final failure)) {
      return Err(AutoswapExecutionFailure(failure.logMessage));
    }

    // 2. Destination + fallback addresses
    final destination = await _getReceiveAddress.execute(
      walletId: recipientWalletId,
    );
    final fallback = await _getReceiveAddress.execute(
      walletId: liquidWallet.id,
    );

    // 3. Create order
    final orderResult = await _swapFacade.createOrder(
      amountSat: BigInt.from(amountSat),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
      destinationAddress: destination.address,
      fallbackAddress: fallback.address,
      purpose: OrderSwapPurpose.autoswap,
      environment: OrderSwapEnvironment.mainnet,
      sourceWalletId: liquidWallet.id,
      destinationWalletId: recipientWalletId,
      note: 'Auto-Transfer',
    );
    if (orderResult case Err(:final failure)) {
      return Err(AutoswapExecutionFailure(failure.logMessage));
    }
    final record = (orderResult as Ok<OrderSwapRecord, SwapFailure>).value;
    final order = record.order!;

    // 4. Validate the server-provided payin address before signing.
    final addressError = _validatePayinAddress(order.payinAddress);
    if (addressError != null) return Err(addressError);

    // 5. Build + sign (no broadcast yet)
    final buildResult = await _buildAndSign(
      liquidWallet: liquidWallet,
      address: order.payinAddress,
      amountSat: order.payinAmountSat.toInt(),
      feeThresholdPercent: settings.feeThresholdPercent,
    );
    if (buildResult case Err(:final failure)) {
      return Err(failure);
    }
    final signedPset = (buildResult as Ok<String, AutoswapFailure>).value;

    // 6. Persist BEFORE broadcast (crash-safe ordering)
    final preparedResult = await _swapFacade.savePreparedPayin(
      localId: record.localId,
      signedTransaction: signedPset,
      isPsbt: true,
    );
    if (preparedResult case Err(:final failure)) {
      return Err(AutoswapExecutionFailure(failure.logMessage));
    }
    final broadcastUnknownResult = await _swapFacade.markBroadcastUnknown(
      record.localId,
    );
    if (broadcastUnknownResult case Err(:final failure)) {
      return Err(AutoswapExecutionFailure(failure.logMessage));
    }

    // 7. Broadcast
    final txid = await _broadcast(
      signedPset: signedPset,
      isTestnet: liquidWallet.isTestnet,
    );

    // 8. Mark paid
    final paidResult = await _swapFacade.markPayinBroadcast(
      localId: record.localId,
      transactionId: txid,
    );
    if (paidResult case Err(:final failure)) {
      return Err(AutoswapExecutionFailure(failure.logMessage));
    }

    await _label(txid, liquidWallet.id);
    return Ok(record.localId);
  }

  // ── Boltz path ─────────────────────────────────────────────────────────

  Future<Result<String, AutoswapFailure>> _executeBoltz({
    required AutoSwap settings,
    required Wallet liquidWallet,
    required Wallet bitcoinWallet,
    required int amountSat,
    required String recipientWalletId,
  }) async {
    final boltzUrl = settings.boltzFallbackUrl;
    if (boltzUrl == null) {
      return const Err(AutoswapBoltzServerRequiredFailure());
    }

    // The swap master key is derived lazily on first Boltz use, not at
    // startup — the derivation is deterministic so nothing is lost.
    await _ensureSwapMasterKey.execute();

    // Create a Boltz repository with the user-configured server.
    final repository = _boltzRepositoryFactory(
      _stripScheme(boltzUrl.toString()),
    );

    // 1. Create chain swap
    final swap = await repository.createLiquidToBitcoinSwap(
      sendWalletId: liquidWallet.id,
      amountSat: amountSat,
      btcElectrumUrl: ApiServiceConstants.bbElectrumUrl,
      lbtcElectrumUrl: ApiServiceConstants.bbLiquidElectrumUrlPath,
      receiveWalletId: recipientWalletId,
    );

    // 2. Validate the server-provided payment address before signing.
    final addressError = _validatePayinAddress(swap.paymentAddress);
    if (addressError != null) return Err(addressError);

    // 3. Build + sign (no broadcast yet)
    final buildResult = await _buildAndSign(
      liquidWallet: liquidWallet,
      address: swap.paymentAddress,
      amountSat: swap.paymentAmount,
      feeThresholdPercent: settings.feeThresholdPercent,
    );
    if (buildResult case Err(:final failure)) {
      return Err(failure);
    }
    final signedPset = (buildResult as Ok<String, AutoswapFailure>).value;

    // 4. Broadcast
    // NOTE: Boltz crash recovery depends on the swap being persisted in
    // BoltzStorageDatasource at creation time (step 1). The paid-status
    // update below is the only post-broadcast write; a crash between
    // broadcast and updatePaidSendSwap leaves the swap in "pending" state,
    // recoverable by a future Boltz watcher reconciling on-chain data.
    final txid = await _broadcast(
      signedPset: signedPset,
      isTestnet: liquidWallet.isTestnet,
    );

    // 5. Mark paid
    final (_, absoluteFees) = await _liquidWalletRepository
        .getPsetSizeAndAbsoluteFees(pset: signedPset);
    await repository.updatePaidSendSwap(
      swapId: swap.id,
      txid: txid,
      absoluteFees: absoluteFees,
    );

    await _label(txid, liquidWallet.id);
    return Ok(swap.id);
  }

  // ── Shared helpers ─────────────────────────────────────────────────────

  /// Builds and signs a PSET, checking the absolute fee against the user's
  /// configured threshold. Does NOT broadcast.
  Future<Result<String, AutoswapFailure>> _buildAndSign({
    required Wallet liquidWallet,
    required String address,
    required int amountSat,
    required double feeThresholdPercent,
  }) async {
    try {
      final pset = await _liquidWalletRepository.buildPset(
        walletId: liquidWallet.id,
        address: address,
        amountSat: amountSat,
        feeRate: const RelativeFee(25),
      );

      // Fee cap: refuse if the absolute fee exceeds the configured
      // percentage of the amount being swapped.
      final (_, absoluteFees) = await _liquidWalletRepository
          .getPsetSizeAndAbsoluteFees(pset: pset);
      final feePercent = (absoluteFees / amountSat) * 100;
      if (feePercent > feeThresholdPercent) {
        return Err(
          AutoswapFeeLimitExceededFailure(
            feePercent: feePercent,
            thresholdPercent: feeThresholdPercent,
          ),
        );
      }

      final signedPset = await _liquidWalletRepository.signPset(
        walletId: liquidWallet.id,
        pset: pset,
      );
      return Ok(signedPset);
    } catch (e) {
      return Err(AutoswapExecutionFailure(e.toString()));
    }
  }

  Future<String> _broadcast({
    required String signedPset,
    required bool isTestnet,
  }) async {
    return _blockchainPort.broadcastLiquidTransaction(
      signedPset: signedPset,
      isTestnet: isTestnet,
    );
  }

  /// Minimal client-side validation of a server-provided payin address.
  /// Returns a failure if the address is empty or implausibly short.
  AutoswapFailure? _validatePayinAddress(String address) {
    if (address.isEmpty || address.length < 20) {
      return const AutoswapInvalidPayinAddressFailure();
    }
    return null;
  }

  Future<void> _label(String txid, String walletId) async {
    await _labelsFacade.store(
      NewLabel.tx(
        transactionId: txid,
        origin: walletId,
        label: 'Auto-Transfer',
      ),
    );
  }

  /// BoltzDatasource expects `host/path` without a scheme.
  static String _stripScheme(String url) =>
      url.replaceFirst('https://', '');
}
