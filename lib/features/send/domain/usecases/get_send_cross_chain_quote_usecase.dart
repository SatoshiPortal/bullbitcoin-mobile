import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/swap_failure_to_send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class GetSendCrossChainQuoteUsecase {
  final SwapFacade _swapFacade;

  const GetSendCrossChainQuoteUsecase(this._swapFacade);

  Future<Result<OrderSwapQuote, SendFailure>> execute({
    required Wallet wallet,
    required BigInt amountSat,
    required bool isInAmountFixed,
  }) async {
    if (amountSat <= BigInt.zero) {
      return const Err(SendInvoiceAmountRequiredFailure());
    }
    final inNetwork = wallet.network.isLiquid
        ? OrderSwapNetwork.liquid
        : OrderSwapNetwork.bitcoin;
    final outNetwork = wallet.network.isLiquid
        ? OrderSwapNetwork.bitcoin
        : OrderSwapNetwork.liquid;
    final result = await _swapFacade.getQuote(
      environment: wallet.network.isTestnet
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
