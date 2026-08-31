import 'package:bull_swap/src/data/bull/exchange_models.dart';
import 'package:bull_swap/src/data/bull/order_swap_amount_codec.dart';
import 'package:bull_swap/src/domain/order_swap.dart';
import 'package:bull_swap/src/domain/order_swap_network.dart';

extension OrderSwapMapper on OrderSwapModel {
  OrderSwap toEntity() => OrderSwap(
    orderId: orderId,
    orderNumber: orderNumber,
    inNetwork: _networkFromMethod(payinMethod),
    outNetwork: _networkFromMethod(payoutMethod),
    payinAmountSat: orderSwapAmountToSats(payinAmount),
    payoutAmountSat: orderSwapAmountToSats(payoutAmount),
    payinCurrency: payinCurrency,
    payoutCurrency: payoutCurrency,
    payinMethod: payinMethod,
    payoutMethod: payoutMethod,
    orderType: orderType,
    orderStatus: orderStatus,
    payinStatus: payinStatus,
    payoutStatus: payoutStatus,
    messageCode: messageCode,
    bitcoinAddress: bitcoinAddress,
    liquidAddress: liquidAddress,
    lightningInvoice: lightningInvoice,
    bitcoinTransactionId: bitcoinTransactionId,
    liquidTransactionId: liquidTransactionId,
    createdAt: createdAt,
    confirmationDeadline: confirmationDeadline,
    completedAt: completedAt,
    sentAt: sentAt,
  );
}

OrderSwapNetwork _networkFromMethod(String method) {
  final normalized = method.toLowerCase();
  if (normalized.contains('lightning')) return OrderSwapNetwork.lightning;
  if (normalized.contains('liquid')) return OrderSwapNetwork.liquid;
  if (normalized.contains('bitcoin')) return OrderSwapNetwork.bitcoin;
  throw FormatException('Unknown swap payment method: $method');
}
