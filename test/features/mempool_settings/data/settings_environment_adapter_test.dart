import 'package:primitives/primitives.dart' show BitcoinUnit, Err;
import 'package:bb_mobile/features/mempool_settings/data/settings_environment_adapter.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements SettingsRepository {}

void main() {
  test('regtest never reaches the historical mempool configuration', () async {
    final settings = _Settings();
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.regtest,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    final adapter = SettingsEnvironmentAdapter(settingsRepository: settings);
    expect(await adapter.getEnvironment(), isA<Err>());
  });
}
