import 'package:bb_mobile/features/electrum_settings/domain/electrum_failure.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:primitives/primitives.dart';

/// A read barrier only: readers never initialize or repair storage.
abstract interface class ElectrumStorageReadinessPort {
  Future<Result<void, ElectrumFailure>> requireReady(
    ElectrumServerNetwork network,
  );
}
