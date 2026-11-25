import 'package:swaps/order_swaps.dart';

import '../send_source.dart';

import 'package:primitives/primitives.dart';

import 'load_send_sources_usecase.dart';

import 'package:address_view/address_view.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/swap_failure_to_send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class CreateSendCrossChainSwapUsecase {
  final OrderSwaps _swapFacade;
  final LoadSendSourcesUsecase _getWallet;
  final AddressView _getReceiveAddress;

  const CreateSendCrossChainSwapUsecase(
    this._swapFacade, {
    required LoadSendSourcesUsecase getWalletUsecase,
    required AddressView getReceiveAddressUsecase,
  }) : _getWallet = getWalletUsecase,
       _getReceiveAddress = getReceiveAddressUsecase;

  @useResult
  Future<Result<OrderSwapRecord, SendFailure>> execute({
    required String walletId,
    required String destinationAddress,
    required bool destinationIsTestnet,
    required int amountSat,
    required bool isInAmountFixed,
    required BigInt quotedCounterpartAmountSat,
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
      if (destinationIsTestnet == wallet.network.isMainnet) {
        return const Err(
          SendInvalidPaymentRequestFailure(
            logMessage: 'Destination network does not match wallet network',
          ),
        );
      }
      if (wallet.isHardwareWallet) {
        return const Err(SendHardwareWalletFailure());
      }

      final inNetwork = wallet.isLiquid
          ? OrderSwapNetwork.liquid
          : OrderSwapNetwork.bitcoin;
      final outNetwork = wallet.isLiquid
          ? OrderSwapNetwork.bitcoin
          : OrderSwapNetwork.liquid;
      final WalletAddress fallback;
      switch (await _getReceiveAddress.receiveAddress(walletId: walletId)) {
        case Ok(:final value):
          fallback = value;
        case Err(:final failure):
          return Err(SendSwapCreationFailure(failure.runtimeType.toString()));
      }
      final result = await _swapFacade.createOrder(
        amountSat: BigInt.from(amountSat),
        isInAmountFixed: isInAmountFixed,
        inNetwork: inNetwork,
        outNetwork: outNetwork,
        destinationAddress: destinationAddress,
        fallbackAddress: fallback.address,
        purpose: OrderSwapPurpose.sendCrossChain,
        environment: !wallet.network.isMainnet
            ? OrderSwapEnvironment.testnet
            : OrderSwapEnvironment.mainnet,
        sourceWalletId: walletId,
        quotedCounterpartAmountSat: quotedCounterpartAmountSat,
        note: note,
      );
      return result.mapErr(mapSwapFailureToSendFailure);
    } catch (error, st) {
      log.severe(
        message: 'Failed to create the send cross-chain swap',
        error: error.runtimeType,
        trace: st,
      );
      return Err(SendSwapCreationFailure(error.runtimeType.toString()));
    }
  }
}
