import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/data/recoverbull_settings_adapter.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:get_it/get_it.dart';

final class SettingsRecoverBullBindings {
  static void setup(GetIt locator) {
    final adapter = RecoverBullSettingsAdapter(
      locator<SettingsRepository>(),
      locator<SqliteDatabase>(),
      locator<Tor>().embedded,
      locator<Tor>(),
    );
    locator.registerSingleton<RecoverBullRoutePort>(adapter);
    locator.registerSingleton<RecoverBullEnvironmentPort>(adapter);
    locator.registerSingleton<RecoverBullLegacySettingsPort>(adapter);
  }
}
