import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class SelectBestWalletUsecase {
  SelectBestWalletUsecase();

  Wallet execute({
    required List<Wallet> wallets,
    required PaymentRequest request,
    int? amountSat,
  }) {
    try {
      // Bitcoin
      if (request is BitcoinPaymentRequest) {
        return _selectBestWallet(
          amountSat ?? 0,
          request.isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet,
          wallets,
        );
      }

      // Liquid
      if (request is LiquidPaymentRequest) {
        return _selectBestWallet(
          amountSat ?? 0,
          request.isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
          wallets,
        );
      }

      //Bip21
      if (request is Bip21PaymentRequest) {
        final amount = amountSat ?? request.amountSat ?? 0;

        return _selectBestWallet(amount, request.network, wallets);
      }

      // Bolt11
      if (request is Bolt11PaymentRequest) {
        try {
          // Use liquid
          return _selectBestWallet(
            request.amountSat,
            Network.liquidMainnet,
            wallets,
          );
        } catch (_) {
          // unless liquid doesn’t have balance, use bitcoin
          return _selectBestWallet(
            request.amountSat,
            Network.bitcoinMainnet,
            wallets,
          );
        }
      }
      // Bolt11
      if (request is LnAddressPaymentRequest) {
        try {
          // Use liquid
          final wallet = _selectBestWallet(
            amountSat ?? 0,
            Network.liquidMainnet,
            wallets,
          );
          return wallet;
        } catch (_) {
          // unless liquid doesn’t have balance, use bitcoin
          return _selectBestWallet(
            amountSat ?? 0,
            Network.bitcoinMainnet,
            wallets,
          );
        }
      }

      throw NotEnoughFundsException();
    } catch (e) {
      log.severe(e.toString());
      rethrow;
    }
  }

  Wallet _selectBestWallet(
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
        return w;
      }
    }

    // Any wallet with enough funds from the same network
    for (final w in wallets) {
      if (w.network == network &&
          w.balanceSat.toInt() > satoshis &&
          w.signer == SignerEntity.local) {
        return w;
      }
    }
    // Any wallet
    // Any wallet with enough funds from the same network
    for (final w in wallets) {
      if (w.balanceSat.toInt() >= satoshis && w.signer == SignerEntity.local) {
        return w;
      }
    }
    throw NotEnoughFundsException();
  }
}

class NotEnoughFundsException implements Exception {
  final String message;

  NotEnoughFundsException({
    this.message = 'Not enough funds available to make this payment.',
  });

  @override
  String toString() {
    return message;
  }
}
