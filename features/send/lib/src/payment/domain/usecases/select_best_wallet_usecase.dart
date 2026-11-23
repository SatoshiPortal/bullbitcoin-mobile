import 'package:satoshifier/payment_request.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:send/src/payment/domain/send_source.dart';
import 'package:primitives/primitives.dart'
    as primitives
    show BitcoinNetwork, LiquidNetwork, Network;
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
      case BitcoinPaymentRequest():
        return _selectBestWallet(
          amountSat ?? 0,
          request.isTestnet
              ? primitives.BitcoinNetwork.testnet
              : primitives.BitcoinNetwork.mainnet,
          wallets,
        );
      case LiquidPaymentRequest():
        return _selectBestWallet(
          amountSat ?? 0,
          request.isTestnet
              ? primitives.LiquidNetwork.testnet
              : primitives.LiquidNetwork.mainnet,
          wallets,
        );
      case Bip21PaymentRequest():
        return _selectBestWallet(
          amountSat ?? request.amountSat ?? 0,
          request.network,
          wallets,
        );
      case Bolt11PaymentRequest():
        // Liquid first for the cheaper swap; fall back to Bitcoin when Liquid
        // cannot cover it.
        return _selectLiquidThenBitcoin(
          request.amountSat,
          isTestnet: request.isTestnet,
          wallets: wallets,
        );
      case LnAddressPaymentRequest():
        return _selectLiquidThenBitcoin(
          amountSat ?? 0,
          isTestnet: false,
          wallets: wallets,
        );
      case PsbtPaymentRequest():
        return const Err(
          SendInvalidPaymentRequestFailure(
            logMessage: 'unsupported payment request',
          ),
        );
    }
  }

  Result<SendSource, SendFailure> _selectLiquidThenBitcoin(
    int amountSat, {
    required bool isTestnet,
    required List<SendSource> wallets,
  }) {
    final liquid = _selectBestWallet(
      amountSat,
      isTestnet
          ? primitives.LiquidNetwork.testnet
          : primitives.LiquidNetwork.mainnet,
      wallets,
    );
    if (liquid case Ok()) return liquid;
    return _selectBestWallet(
      amountSat,
      isTestnet
          ? primitives.BitcoinNetwork.testnet
          : primitives.BitcoinNetwork.mainnet,
      wallets,
    );
  }

  Result<SendSource, SendFailure> _selectBestWallet(
    int satoshis,
    primitives.Network network,
    List<SendSource> wallets,
  ) {
    // Default first
    for (final w in wallets) {
      final balance = w.balanceSat;
      if (balance == null) continue;
      if (w.isDefault &&
          w.network == network &&
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
      if (w.network == network &&
          balance.toInt() > satoshis &&
          w.signsLocally) {
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
