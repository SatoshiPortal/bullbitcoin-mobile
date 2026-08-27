import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/swap_failure_to_send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class CreateSendSwapUsecase {
  final SwapFacade _swapFacade;
  final GetWalletUsecase _getWallet;
  final GetReceiveAddressUsecase _getReceiveAddress;
  final DateTime Function() _now;

  CreateSendSwapUsecase(
    this._swapFacade, {
    required GetWalletUsecase getWalletUsecase,
    required GetReceiveAddressUsecase getReceiveAddressUsecase,
    DateTime Function()? now,
  }) : _getWallet = getWalletUsecase,
       _getReceiveAddress = getReceiveAddressUsecase,
       _now = now ?? DateTime.now;

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
      final wallet = await _getWallet.execute(walletId);
      if (wallet == null) {
        return const Err(SendSwapCreationFailure('Wallet not found'));
      }
      final inNetwork = wallet.network.isLiquid
          ? OrderSwapNetwork.liquid
          : OrderSwapNetwork.bitcoin;
      if (invoice.isTestnet != wallet.network.isTestnet) {
        return const Err(
          SendInvalidPaymentRequestFailure(
            logMessage: 'Invoice network does not match wallet network',
          ),
        );
      }
      if (wallet.isBitcoinHardwareWallet) {
        return const Err(SendHardwareWalletFailure());
      }

      final fallback = await _getReceiveAddress.execute(walletId: walletId);
      final result = await _swapFacade.createOrder(
        amountSat: BigInt.from(amountSat),
        isInAmountFixed: false,
        inNetwork: inNetwork,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: invoice.invoice,
        fallbackAddress: fallback.address,
        purpose: OrderSwapPurpose.sendLightning,
        environment: wallet.network.isTestnet
            ? OrderSwapEnvironment.testnet
            : OrderSwapEnvironment.mainnet,
        sourceWalletId: walletId,
        quotedCounterpartAmountSat: quote?.inAmountSat,
        note: note,
      );
      return result.mapErr(mapSwapFailureToSendFailure);
    } catch (error) {
      return Err(SendSwapCreationFailure(error.toString()));
    }
  }
}
