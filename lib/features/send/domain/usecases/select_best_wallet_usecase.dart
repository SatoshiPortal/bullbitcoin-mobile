import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/features/send/domain/entities/payment_request.dart';
import 'package:flutter/foundation.dart';

class SelectBestWalletUsecase {
  SelectBestWalletUsecase();

  Future<Wallet> execute({
    required List<Wallet> wallets,
    required PaymentRequest request,
    BigInt? amountSat,
  }) async {
    try {
      if (request is BitcoinRequest || request is LiquidRequest) {
        if (amountSat == null) throw 'amountSat should be specified';
      }

      // Bitcoin
      if (request is BitcoinRequest) {
        _selectBestWallet(amountSat!, request.network, wallets);
      }

      // Liquid
      if (request is LiquidRequest) {
        return _selectBestWallet(amountSat!, request.network, wallets);
      }

      //Bip21
      if (request is Bip21Request) {
        final uriAmount = BigInt.tryParse(request.options['amount'] as String);
        final amount = uriAmount ?? amountSat;

        if (amount == null) throw 'The amount of satoshis should be specified';

        return _selectBestWallet(amount, request.network, wallets);
      }

      // Bolt11
      if (request is Bolt11Request) {
        try {
          // Use liquid
          return _selectBestWallet(
            request.amount,
            Network.liquidMainnet,
            wallets,
          );
        } catch (_) {
          // unless liquid doesn’t have balance, use bitcoin
          return _selectBestWallet(
            request.amount,
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
    BigInt satoshis,
    Network network,
    List<Wallet> wallets,
  ) async {
    // Default first
    for (final w in wallets) {
      if (w.isDefault && w.network == network && w.balanceSat >= satoshis) {
        return w;
      }
    }

    // Any wallet with enough funds from the same network
    for (final w in wallets) {
      if (w.network == network && w.balanceSat >= satoshis) {
        return w;
      }
    }

    throw 'not enough funds to process this $PaymentRequest';
  }
}
