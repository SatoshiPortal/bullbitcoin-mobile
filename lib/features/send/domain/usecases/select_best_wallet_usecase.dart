import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';

import 'package:flutter/foundation.dart';

class SelectBestWalletUsecase {
  SelectBestWalletUsecase();

  Future<Wallet> execute({
    required List<Wallet> wallets,
    required PaymentRequest request,
    int? amountSat,
  }) {
    try {
      if (request is BitcoinPaymentRequest || request is LiquidPaymentRequest) {
        if (amountSat == null) throw 'amountSat should be specified';
      }

      // Bitcoin
      if (request is BitcoinPaymentRequest) {
        return _selectBestWallet(
          amountSat!,
          request.isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet,
          wallets,
        );
      }

      // Liquid
      if (request is LiquidPaymentRequest) {
        return _selectBestWallet(
          amountSat!,
          request.isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
          wallets,
        );
      }

      //Bip21
      if (request is Bip21PaymentRequest) {
        final amount = amountSat ?? request.amountSat;

        if (amount == null) throw 'The amount of satoshis should be specified';

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
          return _selectBestWallet(
            0,
            Network.liquidMainnet,
            wallets,
          );
        } catch (_) {
          // unless liquid doesn’t have balance, use bitcoin
          return _selectBestWallet(
            0,
            Network.bitcoinMainnet,
            wallets,
          );
        }
      }

      throw 'no wallet or not enough balance for this $PaymentRequest';
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  Future<Wallet> _selectBestWallet(
    int satoshis,
    Network network,
    List<Wallet> wallets,
  ) async {
    // Default first
    for (final w in wallets) {
      if (w.isDefault &&
          w.network == network &&
          w.balanceSat.toInt() >= satoshis) {
        return w;
      }
    }

    // Any wallet with enough funds from the same network
    for (final w in wallets) {
      if (w.network == network && w.balanceSat.toInt() >= satoshis) {
        return w;
      }
    }

    throw 'not enough funds to process this $PaymentRequest';
  }
}
