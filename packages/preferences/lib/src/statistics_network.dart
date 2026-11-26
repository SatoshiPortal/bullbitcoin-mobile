import 'package:bull_reporting/statistics.dart';

import 'preferences.dart';

/// Adapts the authoritative active environment to the reporting capability.
final class PreferencesStatisticsNetwork implements StatisticsNetwork {
  final Preferences _preferences;

  PreferencesStatisticsNetwork(this._preferences);

  @override
  Future<bool> isMainnet() async {
    if (_preferences.isEnvironmentChanging) return false;
    final mainnet = (await _preferences.readActiveEnvironment()).fold(
      (environment) => environment.isMainnet,
      (_) => false,
    );
    return mainnet && !_preferences.isEnvironmentChanging;
  }

  @override
  Stream<bool> get changes => _preferences.environmentTransitions;
}
