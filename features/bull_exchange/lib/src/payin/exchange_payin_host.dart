import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:labels/labels.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:spend/spend.dart';
import 'package:sync/write.dart' show WalletNativeRuntime;

import 'exchange_payin_ui.dart';

typedef ExchangePayinHost = ({
  Exchange Function() exchange,
  Preferences Function() preferences,
  WalletInventory Function() inventory,
  WalletNativeRuntime Function() native,
  Spend Function() spend,
  Fees Function() fees,
  PayjoinPolicyAccess Function() payjoinPolicy,
  PayjoinSender Function() payjoinSender,
  PayjoinSessions Function() payjoinSessions,
  Labels Function() labels,
  ExchangePayinUi ui,
});
