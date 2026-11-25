import 'package:flutter/widgets.dart';

import 'exchange_payin_wallet.dart';

/// Shows an address or invoice the way the wallet does (the app's
/// AddressViewer).
typedef AddressViewerBuilder = Widget Function(
  BuildContext,
  String, {
  TextStyle? style,
  Color? color,
  TextAlign? textAlign,
});

typedef ExchangePayinUi = ({
  Widget Function(BuildContext, ValueChanged<ExchangePayinWallet>?) walletCards,
  AddressViewerBuilder addressViewer,
  void Function(BuildContext) openWalletHome,
  void Function(BuildContext, String, {required bool returnToExchange})
  openOrder,
  void Function(BuildContext, String) openPayjoinTransaction,
  String brandAsset,
  String successAsset,
});
