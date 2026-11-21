import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_backend_config_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:primitives/primitives.dart';

class CheckSpServerUsecase {
  final LoadSpBackendConfigUsecase _loadConfig;
  final GetSpBackendDefaultsUsecase _getDefaults;
  final TestSpBackendUsecase _testBackend;

  CheckSpServerUsecase({
    required this._loadConfig,
    required this._getDefaults,
    required this._testBackend,
  });

  Future<Result<void, SpFailure>> execute(BitcoinNetwork network) async {
    if (!NetworkCapabilities.supports(
      network,
      NetworkCapability.silentPayments,
    )) {
      return const Err(SpUnsupportedNetwork());
    }
    switch (await _loadConfig.execute()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final config?) when config.network == network:
        return _testBackend.execute(SpBackendKind.blindbit, config.blindbitUrl);
      case Ok():
        return switch (await _getDefaults.execute(network)) {
          Ok(:final value) => _testBackend.execute(
            SpBackendKind.blindbit,
            value.blindbitUrl,
          ),
          Err(:final failure) => Err(failure),
        };
    }
  }
}
