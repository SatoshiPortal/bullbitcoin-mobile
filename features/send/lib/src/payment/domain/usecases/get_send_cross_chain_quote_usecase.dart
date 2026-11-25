import 'package:swaps/order_swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:send/src/payment/domain/send_source.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/swap_failure_to_send_failure.dart';
import 'package:meta/meta.dart';

class GetSendCrossChainQuoteUsecase {
  final OrderSwaps _swapFacade;

  const GetSendCrossChainQuoteUsecase(this._swapFacade);

  @useResult
  Future<Result<OrderSwapQuote, SendFailure>> execute({
    required SendSource wallet,
    required BigInt amountSat,
    required bool isInAmountFixed,
  }) async {
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
    if (amountSat <= BigInt.zero) {
      return const Err(SendInvoiceAmountRequiredFailure());
    }
    final inNetwork = wallet.isLiquid
        ? OrderSwapNetwork.liquid
        : OrderSwapNetwork.bitcoin;
    final outNetwork = wallet.isLiquid
        ? OrderSwapNetwork.bitcoin
        : OrderSwapNetwork.liquid;
    final result = await _swapFacade.getQuote(
      environment: !wallet.network.isMainnet
          ? OrderSwapEnvironment.testnet
          : OrderSwapEnvironment.mainnet,
      amountSat: amountSat,
      isInAmountFixed: isInAmountFixed,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
    );
    return result.mapErr(mapSwapFailureToSendFailure);
  }
}
