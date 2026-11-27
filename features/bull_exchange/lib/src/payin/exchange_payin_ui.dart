import 'package:flutter/widgets.dart';

import 'package:sync/sync.dart' show WalletKey;

typedef ExchangePayinUi = ({
  Widget Function(
    BuildContext,
    ValueChanged<({WalletKey key, String? label, bool isDefault})>?,
  )
  walletCards,
  void Function(BuildContext) openWalletHome,
  String brandAsset,
  String successAsset,
});
