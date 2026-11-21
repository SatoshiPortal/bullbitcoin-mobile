import 'package:electrum/src/domain/electrum_environment.dart';

abstract class EnvironmentPort {
  Future<ElectrumEnvironment> getEnvironment();
}
