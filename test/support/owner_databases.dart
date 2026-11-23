import 'package:bb_mobile/features/swap/data/order_swaps_database.dart';
import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';

void registerTestOwnerDatabases(GetIt locator) {
  locator.registerSingleton(
    OrderSwapsDatabase(NativeDatabase.memory()),
    dispose: (database) => database.close(),
  );
}
