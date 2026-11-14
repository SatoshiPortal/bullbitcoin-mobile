import 'package:bb_mobile/features/electrum_settings/domain/electrum_environment.dart';

abstract class EnvironmentPort {
  Future<ElectrumEnvironment> getEnvironment();
}
