import 'package:address_view/address_view.dart';
import 'package:bull_ark/bull_ark.dart' show ArkFacade;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:coins/coins.dart';
import 'package:labels/labels.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:receive/receive.dart';
import 'package:secrets/secrets.dart';
import 'package:signers/signers.dart' show SignerDevice;
import 'package:silent/silent.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';
import 'package:sync/sync.dart' show WalletKey, SyncFailure;
import 'package:sync/write.dart' show WalletNativeRuntime;
import 'package:transactions/transactions.dart';

/// Capabilities shared with the rest of the foreground app.
typedef SendPaymentDependencies = ({
  WalletInventory inventory,
  WalletNativeRuntime native,
  Future<Result<void, SyncFailure>> Function(WalletKey) synchronize,
  Stream<WalletKey> finishedSyncs,
  Future<Result<SignerDevice?, Failure>> Function(String) readSignerDevice,
  Preferences preferences,
  Coins coins,
  AddressView addresses,
  Receive receive,
  Swaps swaps,
  OrderSwaps orders,
  Payjoin payjoin,
  Transactions transactions,
  Labels labels,
  Silent silent,
  ArkFacade? ark,
});
