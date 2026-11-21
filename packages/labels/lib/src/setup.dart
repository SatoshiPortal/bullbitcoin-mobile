import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:labels/src/public/labels_facade.dart';
import 'package:sync/sync.dart';

void setupLabels(
  GetIt services, {
  required GeneratedDatabase database,
  required Future<Sync> Function() sync,
  required Future<Wallet> Function(String) openWallet,
}) {
  services.registerLazySingleton(
    () => LabelsFacade.open(
      database: database,
      sync: sync,
      openWallet: openWallet,
    ),
  );
  services.registerLazySingleton<ReservedAddressPort>(
    () => services<LabelsFacade>().reservedAddresses(),
  );
}
