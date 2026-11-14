import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_failure.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_environment.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

abstract class ElectrumSettingsRepository {
  @useResult
  Future<Result<void, ElectrumFailure>> save(ElectrumSettings settings);
  @useResult
  Future<Result<List<ElectrumSettings>, ElectrumFailure>> fetchAll();
  @useResult
  Future<Result<List<ElectrumSettings>, ElectrumFailure>> fetchByEnvironment(
    ElectrumEnvironment environment,
  );
  @useResult
  Future<Result<ElectrumSettings, ElectrumFailure>> fetchByNetwork(
    ElectrumServerNetwork network,
  );
}
