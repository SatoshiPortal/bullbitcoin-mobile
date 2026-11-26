import 'package:flutter/widgets.dart';

import 'exchange_payin_wallet.dart';

typedef ExchangePayinUi = ({
  Widget Function(BuildContext, ValueChanged<ExchangePayinWallet>?) walletCards,
  void Function(BuildContext) openWalletHome,
  String brandAsset,
  String successAsset,
});
