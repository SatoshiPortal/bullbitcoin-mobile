import 'package:bb_mobile/features/swap/data/order_swaps_database.dart';
import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:swaps/swaps.dart';

void registerTestOwnerDatabases(GetIt locator) {
  locator.registerSingleton(
    OrderSwapsDatabase(NativeDatabase.memory()),
    dispose: (database) => database.close(),
  );
  locator.registerSingleton(
    BoltzSwapsDatabase(NativeDatabase.memory()),
    dispose: (database) => database.close(),
  );
  locator.registerSingleton(
    BoltzSwapsDatabase(NativeDatabase.memory()),
    instanceName: 'regtest',
    dispose: (database) => database.close(),
  );
}
