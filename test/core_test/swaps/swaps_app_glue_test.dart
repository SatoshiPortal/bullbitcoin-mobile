import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/swaps_adapters.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Wallets extends Mock implements WalletRepository {}

void main() {
  test('regtest hands the engine no wallets and no swap key', () async {
    final settings = _Settings();
    final wallets = _Wallets();
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '/unused');
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.regtest,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    final glue = SwapsAppGlue(
      walletRepository: wallets,
      settingsRepository: settings,
      secrets: secrets,
    );

    expect(await glue.wallets(isTestnet: true), isEmpty);
    expect(await glue.swapMasterKey(isTestnet: true), isNull);
    verifyZeroInteractions(wallets);
  });
}
