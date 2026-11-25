import 'package:swaps/order_swaps.dart';

import '../send_source.dart';

import 'package:primitives/primitives.dart';
import 'package:satoshifier/payment_request.dart';

import 'load_send_sources_usecase.dart';

import 'package:address_view/address_view.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/swap_failure_to_send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class CreateSendSwapUsecase {
  final OrderSwaps _swapFacade;
  final LoadSendSourcesUsecase _getWallet;
  final AddressView _getReceiveAddress;
  final DateTime Function() _now;

  CreateSendSwapUsecase(
    this._swapFacade, {
    required LoadSendSourcesUsecase getWalletUsecase,
    required AddressView getReceiveAddressUsecase,
    DateTime Function()? now,
  }) : _getWallet = getWalletUsecase,
       _getReceiveAddress = getReceiveAddressUsecase,
       _now = now ?? DateTime.now;

  @useResult
  Future<Result<OrderSwapRecord, SendFailure>> execute({
    required String walletId,
    required Bolt11PaymentRequest invoice,
    required int amountSat,
    OrderSwapQuote? quote,
    String? note,
  }) async {
    if (amountSat <= 0) {
      return const Err(SendInvoiceAmountRequiredFailure());
    }
    if (invoice.amountSat > 0 && invoice.amountSat != amountSat) {
      return const Err(
        SendInvalidPaymentRequestFailure(
          logMessage: 'Invoice amount does not match requested amount',
        ),
      );
    }
    if (invoice.expiresAt <= _now().millisecondsSinceEpoch ~/ 1000) {
      return const Err(SendInvoiceExpiredFailure());
    }

    try {
      final SendSource? wallet;
      switch (await _getWallet.read(walletId)) {
        case Ok(:final value):
          wallet = value;
        case Err(:final failure):
          return Err(failure);
      }
      if (wallet == null) {
        return const Err(SendSwapCreationFailure('Wallet not found'));
      }
      if (!NetworkCapabilities.supports(
            wallet.network,
            NetworkCapability.swaps,
          ) ||
          !NetworkCapabilities.supports(
            wallet.network,
            NetworkCapability.exchange,
          )) {
        return const Err(SendSwapRouteUnavailableFailure());
      }
      final inNetwork = wallet.isLiquid
          ? OrderSwapNetwork.liquid
          : OrderSwapNetwork.bitcoin;
      if (invoice.isTestnet == wallet.network.isMainnet) {
        return const Err(
          SendInvalidPaymentRequestFailure(
            logMessage: 'Invoice network does not match wallet network',
          ),
        );
      }
      if (wallet.isBitcoinHardwareWallet) {
        return const Err(SendHardwareWalletFailure());
      }

      final WalletAddress fallback;
      switch (await _getReceiveAddress.receiveAddress(walletId: walletId)) {
        case Ok(:final value):
          fallback = value;
        case Err(:final failure):
          return Err(SendSwapCreationFailure(failure.runtimeType.toString()));
      }
      final result = await _swapFacade.createOrder(
        amountSat: BigInt.from(amountSat),
        isInAmountFixed: false,
        inNetwork: inNetwork,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: invoice.invoice,
        fallbackAddress: fallback.address,
        purpose: OrderSwapPurpose.sendLightning,
        environment: !wallet.network.isMainnet
            ? OrderSwapEnvironment.testnet
            : OrderSwapEnvironment.mainnet,
        sourceWalletId: walletId,
        quotedCounterpartAmountSat: quote?.inAmountSat,
        note: note,
      );
      return result.mapErr(mapSwapFailureToSendFailure);
    } catch (error, st) {
      log.severe(
        message: 'Failed to create the send swap',
        error: error.runtimeType,
        trace: st,
      );
      return Err(SendSwapCreationFailure(error.runtimeType.toString()));
    }
  }
}
