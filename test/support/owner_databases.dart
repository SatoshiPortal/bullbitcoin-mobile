import 'package:swaps/testing.dart';
import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:swaps/swaps.dart';

void registerTestOwnerDatabases(GetIt locator) {
  final fixture = orderSwapsForTesting();
  locator.registerSingleton(fixture.orders, dispose: (_) => fixture.close());
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
