import 'package:bb_mobile/core/locator/core_locator_datasources.dart';
import 'package:bb_mobile/core/locator/core_locator_repositories.dart';
import 'package:bb_mobile/core/locator/core_locator_services.dart';
import 'package:bb_mobile/core/locator/core_locator_usecases.dart';

class CoreLocator {
  static Future<void> setup() async {
    await registerDatasources();
    await registerRepositories();
    await registerServices();
    await registerUsecases();
  }
}
