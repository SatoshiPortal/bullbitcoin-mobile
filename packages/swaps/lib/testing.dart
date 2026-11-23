import 'package:drift/native.dart';

import 'order_swaps.dart';
import 'src/orders/data/order_swaps_database.dart';
import 'src/orders/data/order_swaps_store.dart';

({OrderSwaps orders, Future<void> Function() close}) orderSwapsForTesting() {
  final database = OrderSwapsDatabase(NativeDatabase.memory());
  return (orders: createOrderSwaps(database), close: database.close);
}
