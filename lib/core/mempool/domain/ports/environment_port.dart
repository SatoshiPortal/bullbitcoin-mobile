import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

abstract class MempoolEnvironmentPort {
  Future<Environment> getEnvironment();
}
