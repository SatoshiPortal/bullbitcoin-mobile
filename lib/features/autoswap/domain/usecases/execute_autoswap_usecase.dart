import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/ports/blockchain_port.dart';
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
  final LabelsFacade _labelsFacade;

  ExecuteAutoswapUsecase({
    required this._getSettings,
    required this._walletRepository,
    required this._liquidWalletRepository,
    required this._blockchainPort,
    required this._getReceiveAddress,
    required this._swapFacade,
    required this._boltzRepositoryFactory,
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

    // 4. Build + sign + broadcast
    final txResult = await _buildSignBroadcast(
      liquidWallet: liquidWallet,
      address: order.payinAddress,
      amountSat: order.payinAmountSat.toInt(),
    );
    if (txResult case Err(:final failure)) {
      return Err(failure);
    }
    final (signedPset, txid) = (txResult as Ok<(String, String), AutoswapFailure>).value;

    // 5. Persist state transitions
    await _swapFacade.savePreparedPayin(
      localId: record.localId,
      signedTransaction: signedPset,
      isPsbt: true,
    );
    await _swapFacade.markBroadcastUnknown(record.localId);
    await _swapFacade.markPayinBroadcast(
      localId: record.localId,
      transactionId: txid,
    );

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

    // 2. Build + sign + broadcast
    final txResult = await _buildSignBroadcast(
      liquidWallet: liquidWallet,
      address: swap.paymentAddress,
      amountSat: swap.paymentAmount,
    );
    if (txResult case Err(:final failure)) {
      return Err(failure);
    }
    final (signedPset, txid) = (txResult as Ok<(String, String), AutoswapFailure>).value;

    // 3. Mark paid
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

  Future<Result<(String, String), AutoswapFailure>> _buildSignBroadcast({
    required Wallet liquidWallet,
    required String address,
    required int amountSat,
  }) async {
    try {
      final pset = await _liquidWalletRepository.buildPset(
        walletId: liquidWallet.id,
        address: address,
        amountSat: amountSat,
        feeRate: const RelativeFee(25),
      );
      final signedPset = await _liquidWalletRepository.signPset(
        walletId: liquidWallet.id,
        pset: pset,
      );
      final txid = await _blockchainPort.broadcastLiquidTransaction(
        signedPset: signedPset,
        isTestnet: liquidWallet.isTestnet,
      );
      return Ok((signedPset, txid));
    } catch (e) {
      return Err(AutoswapExecutionFailure(e.toString()));
    }
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
