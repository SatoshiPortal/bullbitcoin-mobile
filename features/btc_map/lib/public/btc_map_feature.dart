import 'package:bull_ui/bull_ui.dart' show LocalizationsDelegate;
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../generated/l10n/btc_map_localizations.dart';
import '../src/bull_map.dart';
import '../src/map_locator.dart';
import '../src/ui/map_router.dart';

/// Application-shell composition for the BTC Map feature.
abstract final class BtcMapFeature {
  static Future<void> initialize() async {
    BullMap.init(cacheDirectory: (await getApplicationCacheDirectory()).path);
  }

  static void setup(GetIt locator) => MapLocator.setup(locator);

  static String get routeName => MapRouter.name;

  static GoRoute get route => MapRouter.route;

  static LocalizationsDelegate<BtcMapLocalizations> get localizationsDelegate =>
      BtcMapLocalizations.delegate;
}
