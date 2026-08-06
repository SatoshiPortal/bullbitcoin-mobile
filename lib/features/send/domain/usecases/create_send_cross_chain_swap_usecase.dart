import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/swap_failure_to_send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class CreateSendCrossChainSwapUsecase {
  final SwapFacade _swapFacade;
  final GetWalletUsecase _getWallet;
  final GetReceiveAddressUsecase _getReceiveAddress;

  const CreateSendCrossChainSwapUsecase(
    this._swapFacade, {
    required GetWalletUsecase getWalletUsecase,
    required GetReceiveAddressUsecase getReceiveAddressUsecase,
  }) : _getWallet = getWalletUsecase,
       _getReceiveAddress = getReceiveAddressUsecase;

  Future<Result<OrderSwapRecord, SendFailure>> execute({
    required String walletId,
    required String destinationAddress,
    required bool destinationIsTestnet,
    required int amountSat,
    required bool isInAmountFixed,
    String? note,
  }) async {
    if (amountSat <= 0 || destinationAddress.isEmpty) {
      return const Err(
        SendInvalidPaymentRequestFailure(
          logMessage: 'Cross-chain destination and amount are required',
        ),
      );
    }
    try {
      final wallet = await _getWallet.execute(walletId);
      if (wallet == null) {
        return const Err(SendSwapCreationFailure('Wallet not found'));
      }
      if (destinationIsTestnet != wallet.network.isTestnet) {
        return const Err(
          SendInvalidPaymentRequestFailure(
            logMessage: 'Destination network does not match wallet network',
          ),
        );
      }
      if (wallet.isHardwareWallet) {
        return const Err(SendHardwareWalletFailure());
      }

      final inNetwork = wallet.network.isLiquid
          ? OrderSwapNetwork.liquid
          : OrderSwapNetwork.bitcoin;
      final outNetwork = wallet.network.isLiquid
          ? OrderSwapNetwork.bitcoin
          : OrderSwapNetwork.liquid;
      final fallback = await _getReceiveAddress.execute(walletId: walletId);
      final result = await _swapFacade.createOrder(
        amountSat: BigInt.from(amountSat),
        isInAmountFixed: isInAmountFixed,
        inNetwork: inNetwork,
        outNetwork: outNetwork,
        destinationAddress: destinationAddress,
        fallbackAddress: fallback.address,
        purpose: OrderSwapPurpose.sendCrossChain,
        environment: wallet.network.isTestnet
            ? OrderSwapEnvironment.testnet
            : OrderSwapEnvironment.mainnet,
        sourceWalletId: walletId,
        note: note,
      );
      return result.mapErr(mapSwapFailureToSendFailure);
    } catch (error) {
      return Err(SendSwapCreationFailure(error.toString()));
    }
  }
}
