import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/swap_failure_to_send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:meta/meta.dart';

class GetSendSwapQuoteUsecase {
  final SwapFacade _swapFacade;

  const GetSendSwapQuoteUsecase(this._swapFacade);

  @useResult
  Future<Result<OrderSwapQuote, SendFailure>> execute({
    required Wallet wallet,
    required BigInt amountSat,
  }) async {
    if (!NetworkCapabilities.supports(
      wallet.network.shared,
      NetworkCapability.swaps,
    )) {
      return const Err(SendSwapRouteUnavailableFailure());
    }
    if (amountSat <= BigInt.zero) {
      return const Err(SendInvoiceAmountRequiredFailure());
    }
    final inNetwork = wallet.network.isLiquid
        ? OrderSwapNetwork.liquid
        : OrderSwapNetwork.bitcoin;
    final result = await _swapFacade.getQuote(
      environment: wallet.network.requireHistoricalTestnet()
          ? OrderSwapEnvironment.testnet
          : OrderSwapEnvironment.mainnet,
      amountSat: amountSat,
      isInAmountFixed: false,
      inNetwork: inNetwork,
      outNetwork: OrderSwapNetwork.lightning,
    );
    return result.mapErr(mapSwapFailureToSendFailure);
  }
}
