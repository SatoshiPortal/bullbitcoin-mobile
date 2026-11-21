import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:labels/labels.dart';
import 'package:labels/src/data/drift_labels_repository.dart';
import 'package:labels/src/data/payjoin_labels_adapter.dart';
import 'package:labels/src/data/reserved_address_port_impl.dart';
import 'package:sync/sync.dart';

void setupLabels(
  GetIt services, {
  required GeneratedDatabase database,
  required Future<Sync> Function() sync,
  required Future<Wallet> Function(String) openWallet,
}) {
  services.registerLazySingleton(
    () => Labels.open(database: database, sync: sync, openWallet: openWallet),
  );
  services.registerLazySingleton<ReservedAddressPort>(
    () => ReservedAddressPortImpl(DriftLabelsRepository(database: database)),
  );
  services.registerLazySingleton<PayjoinLabelsPort>(
    () => AppPayjoinLabelsAdapter((label) async {
      await services<Labels>().store(label);
    }),
  );
}
