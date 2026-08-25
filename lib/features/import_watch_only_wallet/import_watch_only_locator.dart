import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_input_parser.dart';
import 'package:get_it/get_it.dart';

class ImportWatchOnlyLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<WatchOnlyInputParser>(
      () => WatchOnlyInputParser(locator<BitcoinDescriptorPort>()),
    );

    // Use cases
    locator.registerFactory<ParseWatchOnlyInputUsecase>(
      () => ParseWatchOnlyInputUsecase(
        locator<WatchOnlyInputParser>(),
        locator<GetSettingsUsecase>(),
        locator<SeedVerificationPort>(),
      ),
    );

    locator.registerFactory<ImportWatchOnlyDescriptorUsecase>(
      () => ImportWatchOnlyDescriptorUsecase(locator<BitcoinDescriptorPort>()),
    );

    locator.registerFactory<ImportWatchOnlyXpubUsecase>(
      () => ImportWatchOnlyXpubUsecase(locator<BitcoinDescriptorPort>()),
    );
  }
}
