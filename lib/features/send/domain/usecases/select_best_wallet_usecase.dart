import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class SelectBestWalletUsecase {
  SelectBestWalletUsecase();

  /// Logs once, for the outcome the caller actually gets. The individual
  /// attempts stay silent: `_selectLiquidThenBitcoin` runs two of them, so
  /// logging per attempt reported a warning for a selection that then
  /// succeeded, and two warnings for one that failed.
  @useResult
  Result<Wallet, SendFailure> execute({
    required List<Wallet> wallets,
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

  Result<Wallet, SendFailure> _select({
    required List<Wallet> wallets,
    required PaymentRequest request,
    int? amountSat,
  }) {
    switch (request) {
      case BitcoinPaymentRequest():
        return _selectBestWallet(
          amountSat ?? 0,
          request.isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet,
          wallets,
        );
      case LiquidPaymentRequest():
        return _selectBestWallet(
          amountSat ?? 0,
          request.isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
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

  Result<Wallet, SendFailure> _selectLiquidThenBitcoin(
    int amountSat, {
    required bool isTestnet,
    required List<Wallet> wallets,
  }) {
    final liquid = _selectBestWallet(
      amountSat,
      isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
      wallets,
    );
    if (liquid case Ok()) return liquid;
    return _selectBestWallet(
      amountSat,
      isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet,
      wallets,
    );
  }

  Result<Wallet, SendFailure> _selectBestWallet(
    int satoshis,
    Network network,
    List<Wallet> wallets,
  ) {
    // Default first
    for (final w in wallets) {
      if (w.isDefault &&
          w.network == network &&
          w.signer == SignerEntity.local &&
          w.balanceSat.toInt() > satoshis &&
          w.balanceSat.toInt() != 0) {
        return Ok(w);
      }
    }

    // Any wallet with enough funds from the same network
    for (final w in wallets) {
      if (w.network == network &&
          w.balanceSat.toInt() > satoshis &&
          w.signer == SignerEntity.local) {
        return Ok(w);
      }
    }

    // Any wallet with enough funds
    for (final w in wallets) {
      if (w.balanceSat.toInt() >= satoshis && w.signer == SignerEntity.local) {
        return Ok(w);
      }
    }

    return const Err(SendInsufficientBalanceFailure('no wallet covers it'));
  }
}
