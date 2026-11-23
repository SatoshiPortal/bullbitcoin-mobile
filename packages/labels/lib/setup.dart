import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:get_it/get_it.dart';
import 'package:labels/labels.dart';
import 'package:labels/src/public/labels.dart' show LabelsSetup;
import 'package:labels/src/data/payjoin_labels_adapter.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

export 'src/public/labels.dart' show LabelsSetup;

void setupLabels(GetIt services, Labels labels) {
  services.registerSingleton<Labels>(
    labels,
    dispose: (value) async {
      final closed = await value.close();
      if (closed case Err(:final failure)) {
        log.warning('Labels close unconfirmed', error: failure.runtimeType);
      }
    },
  );
  services.registerSingleton<FreezeStorePort>(labels.freezes);
  services.registerSingleton<ReservedAddressPort>(labels.reservedAddresses);
  services.registerLazySingleton<PayjoinLabelsPort>(
    () => AppPayjoinLabelsAdapter((label) async {
      await services<Labels>().store(label);
    }),
  );
}
