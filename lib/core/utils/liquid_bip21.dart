import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

// TODO: Support asset_id when reading - required for L-USDT
class LiquidBip21 {
  static PaymentRequest decode(String url) {
    final uri = Uri.parse(url);
    final urnScheme = uri.scheme;
    final address = uri.path;
    Network network;
    if (urnScheme == 'liquidnetwork' || urnScheme == 'liquid') {
      network = Network.liquidMainnet;
    } else if (urnScheme == 'liquidtestnet') {
      network = Network.liquidTestnet;
    } else {
      throw 'Invalid URN scheme for liquid bip21';
    }
    final label = uri.queryParameters['label'] ?? '';
    final message = uri.queryParameters['message'] ?? '';
    final lightning = uri.queryParameters['lightning'] ?? '';
    final pj = uri.queryParameters['pj'] ?? '';
    final pjos = uri.queryParameters['pjos'] ?? '';
    final amountStr = uri.queryParameters['amount'];
    int? amountSat;
    if (amountStr != null && amountStr.isNotEmpty) {
      final amount = double.tryParse(amountStr);
      if (amount != null) {
        amountSat = ConvertAmount.btcToSats(amount);
      }
    }
    return PaymentRequest.bip21(
      network: network,
      address: address,
      uri: url,
      label: label,
      message: message,
      amountSat: amountSat,
      lightning: lightning,
      pj: pj,
      pjos: pjos,
    );
  }
}
