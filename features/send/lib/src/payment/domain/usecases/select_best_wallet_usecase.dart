import 'package:satoshifier/payment_request.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:send/src/payment/domain/send_source.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class SelectBestWalletUsecase {
  SelectBestWalletUsecase();

  /// Logs once, for the outcome the caller actually gets. The individual
  /// attempts stay silent: `_selectLiquidThenBitcoin` runs two of them, so
  /// logging per attempt reported a warning for a selection that then
  /// succeeded, and two warnings for one that failed.
  @useResult
  Result<SendSource, SendFailure> execute({
    required List<SendSource> wallets,
    required PaymentRequest request,
    int? amountSat,
  }) {
    final result = _select(
      wallets: wallets,
      request: request,
      amountSat: amountSat,
    );
    if (result case Err(:final failure)) {
      log.warning(
        'No wallet selected for this payment',
        error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
      );
    }
    return result;
  }

  Result<SendSource, SendFailure> _select({
    required List<SendSource> wallets,
    required PaymentRequest request,
    int? amountSat,
  }) {
    switch (request) {
      case BitcoinPaymentRequest(:final isTestnet):
        return _selectBestWallet(
          amountSat ?? 0,
          (wallet) => wallet.isBitcoin && _isOnEnvironment(wallet, isTestnet),
          wallets,
        );
      case LiquidPaymentRequest(:final isTestnet):
        return _selectBestWallet(
          amountSat ?? 0,
          (wallet) => wallet.isLiquid && _isOnEnvironment(wallet, isTestnet),
          wallets,
        );
      case Bip21PaymentRequest(:final network):
        return _selectBestWallet(
          amountSat ?? request.amountSat ?? 0,
          (wallet) => wallet.network == network,
          wallets,
        );
      case Bolt11PaymentRequest(:final amountSat, :final isTestnet):
        // Liquid first for the cheaper swap; fall back to Bitcoin when Liquid
        // cannot cover it.
        return _selectLiquidThenBitcoin(
          amountSat,
          (wallet) => _isOnEnvironment(wallet, isTestnet),
          wallets,
        );
      case LnAddressPaymentRequest():
        // A Lightning address names no network; the wallets are already
        // those of the active environment.
        return _selectLiquidThenBitcoin(amountSat ?? 0, (_) => true, wallets);
      case PsbtPaymentRequest():
        return const Err(
          SendInvalidPaymentRequestFailure(
            logMessage: 'unsupported payment request',
          ),
        );
    }
  }

  /// A legacy request only knows whether it is a test network, which covers
  /// both testnet and regtest wallets.
  static bool _isOnEnvironment(SendSource wallet, bool isTestnet) =>
      !wallet.network.isMainnet == isTestnet;

  Result<SendSource, SendFailure> _selectLiquidThenBitcoin(
    int amountSat,
    bool Function(SendSource wallet) isOnEnvironment,
    List<SendSource> wallets,
  ) {
    final liquid = _selectBestWallet(
      amountSat,
      (wallet) => wallet.isLiquid && isOnEnvironment(wallet),
      wallets,
    );
    if (liquid case Ok()) return liquid;
    return _selectBestWallet(
      amountSat,
      (wallet) => wallet.isBitcoin && isOnEnvironment(wallet),
      wallets,
    );
  }

  Result<SendSource, SendFailure> _selectBestWallet(
    int satoshis,
    bool Function(SendSource wallet) isCandidate,
    List<SendSource> wallets,
  ) {
    // Default first
    for (final w in wallets) {
      final balance = w.balanceSat;
      if (balance == null) continue;
      if (w.isDefault &&
          isCandidate(w) &&
          w.signsLocally &&
          balance.toInt() > satoshis &&
          balance.toInt() != 0) {
        return Ok(w);
      }
    }

    // Any wallet with enough funds from the same network
    for (final w in wallets) {
      final balance = w.balanceSat;
      if (balance == null) continue;
      if (isCandidate(w) && balance.toInt() > satoshis && w.signsLocally) {
        return Ok(w);
      }
    }

    // Any wallet with enough funds
    for (final w in wallets) {
      final balance = w.balanceSat;
      if (balance == null) continue;
      if (balance.toInt() >= satoshis && w.signsLocally) {
        return Ok(w);
      }
    }

    return const Err(SendInsufficientBalanceFailure('no wallet covers it'));
  }
}
