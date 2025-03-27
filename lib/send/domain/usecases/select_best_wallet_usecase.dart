import 'package:bb_mobile/_core/domain/entities/payment_request.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:flutter/foundation.dart';

class SelectBestWalletUsecase {
  final WalletManagerService _walletManager;

  SelectBestWalletUsecase(this._walletManager);

  Future<Wallet> execute({
    required PaymentRequest request,
    BigInt? amountSat,
  }) async {
    try {
      final wallets = await _walletManager.getWallets();

      if (request is BitcoinRequest || request is LiquidRequest) {
        if (amountSat == null) throw 'amountSat should be specified';
      }

      // Bitcoin
      if (request is BitcoinRequest) {
        _selectBestWallet(amountSat!, request.network, wallets);
      }

      // Liquid
      if (request is LiquidRequest) {
        _selectBestWallet(amountSat!, request.network, wallets);
      }

      //Bip21
      if (request is Bip21Request) {
        final uriAmount = BigInt.tryParse(request.options['amount'] as String);
        final amount = uriAmount ?? amountSat;

        if (amount == null) throw 'The amount of satoshis should be specified';

        _selectBestWallet(amount, request.network, wallets);
      }

      // Bolt11
      if (request is Bolt11Request) {
        try {
          // Use liquid
          _selectBestWallet(request.amount, Network.liquidMainnet, wallets);
        } catch (_) {
          // unless liquid doesn’t have balance, use bitcoin
          _selectBestWallet(request.amount, Network.bitcoinMainnet, wallets);
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
