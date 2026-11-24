import 'package:preferences/preferences.dart' show ActiveEnvironmentReader;
import 'package:primitives/primitives.dart';
import 'package:wallet_import/src/domain/import_failure.dart';

class ReadWatchOnlyNetworkUsecase {
  final ActiveEnvironmentReader _preferences;

  const ReadWatchOnlyNetworkUsecase(this._preferences);

  Future<Result<NetworkEnv, ImportWatchOnlyFailure>> execute() async =>
      switch (await _preferences.readActiveEnvironment()) {
        Ok(:final value) => Ok(value.networkEnv),
        Err() => const Err(ImportFailedFailure()),
      };
}
