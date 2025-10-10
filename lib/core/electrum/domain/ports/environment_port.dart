import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';

abstract class EnvironmentPort {
  Future<ElectrumEnvironment> getEnvironment();
}
