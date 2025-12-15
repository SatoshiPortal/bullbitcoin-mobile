import 'package:bb_mobile/core_deprecated/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_server_network.dart';

abstract class ElectrumSettingsRepository {
  Future<void> save(ElectrumSettings settings);
  Future<List<ElectrumSettings>> fetchAll();
  Future<List<ElectrumSettings>> fetchByEnvironment(
    ElectrumEnvironment environment,
  );
  Future<ElectrumSettings> fetchByNetwork(ElectrumServerNetwork network);
}
