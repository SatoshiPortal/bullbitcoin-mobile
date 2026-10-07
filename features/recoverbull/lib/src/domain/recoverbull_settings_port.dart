import 'entities/recoverbull_network.dart';
import 'entities/recoverbull_tor_settings.dart';

abstract interface class RecoverBullSettingsPort {
  Future<RecoverBullTorSettings> fetch();

  /// The Bitcoin network the app currently runs on: testnet in testnet mode,
  /// mainnet otherwise.
  Future<RecoverBullNetwork> fetchNetwork();
}
