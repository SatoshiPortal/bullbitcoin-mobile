import 'package:flutter/widgets.dart';

import 'exchange_payin_wallet.dart';

typedef ExchangePayinUi = ({
  Widget Function(BuildContext, ValueChanged<ExchangePayinWallet>?) walletCards,
  Widget Function(
    BuildContext,
    String, {
    TextStyle? style,
    Color? color,
    TextAlign? textAlign,
  })
  addressViewer,
  void Function(BuildContext) openWalletHome,
  void Function(BuildContext, String, {required bool returnToExchange})
  openOrder,
  void Function(BuildContext, String) openPayjoinTransaction,
  String brandAsset,
  String successAsset,
});
