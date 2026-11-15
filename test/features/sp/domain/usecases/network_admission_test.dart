import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_secret_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as app;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

class SettingsMock extends Mock implements SettingsRepository {}

class WalletsMock extends Mock implements WalletRepository {}

class WalletMock extends Mock implements app.Wallet {}

void main() {
  test('SP feature gate must be closed while app is on regtest', () async {
    final settings = SettingsMock();
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.regtest,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
        isSuperuser: true,
        isDevModeEnabled: true,
      ),
    );
    expect(
      await GetSpFeatureGateUsecase(settingsRepository: settings).execute(),
      isFalse,
    );
  });
  test('testnet SP custody lookup must not select a regtest default', () async {
    final wallets = WalletsMock();
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final imported = await secrets.import(
      words: [...List.filled(11, 'abandon'), 'about'],
    );
    final regtestSecret = (imported as Ok<Secret, SecretFailure>).value;
    final regtestWallet = WalletMock();
    final testnetWallet = WalletMock();
    when(() => regtestWallet.network).thenReturn(app.Network.bitcoinRegtest);
    when(() => regtestWallet.masterFingerprint)
        .thenReturn(regtestSecret.id.hex);
    when(() => testnetWallet.network).thenReturn(app.Network.bitcoinTestnet);
    when(() => testnetWallet.masterFingerprint).thenReturn('11223344');
    when(() => wallets.getWallets(onlyDefaults: true, onlyBitcoin: true))
        .thenAnswer((_) async => Ok([regtestWallet, testnetWallet]));
    final result = await GetSpSecretUsecase(
      walletRepository: wallets,
      secrets: secrets,
    ).execute(BitcoinNetwork.testnet);
    expect(
      result,
      isA<Err<Secret, SpFailure>>(),
      reason: 'The testnet secret is absent; a regtest secret must never be returned',
    );
  });
  for (final regtestFirst in [true, false]) {
    test('testnet custody is exact with regtestFirst=$regtestFirst', () async {
      final wallets = WalletsMock();
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(scratchDirectory: () async => '/tmp');
      final regtestResult = await secrets.import(
        words: [...List.filled(11, 'abandon'), 'about'],
      );
      final testnetResult = await secrets.import(
        words: 'legal winner thank year wave sausage worth useful legal winner thank yellow'
            .split(' '),
      );
      final regtestSecret = (regtestResult as Ok<Secret, SecretFailure>).value;
      final testnetSecret = (testnetResult as Ok<Secret, SecretFailure>).value;
      final regtestWallet = WalletMock();
      final testnetWallet = WalletMock();
      when(() => regtestWallet.network).thenReturn(app.Network.bitcoinRegtest);
      when(() => regtestWallet.masterFingerprint)
          .thenReturn(regtestSecret.id.hex);
      when(() => testnetWallet.network).thenReturn(app.Network.bitcoinTestnet);
      when(() => testnetWallet.masterFingerprint)
          .thenReturn(testnetSecret.id.hex);
      when(() => wallets.getWallets(onlyDefaults: true, onlyBitcoin: true))
          .thenAnswer(
            (_) async => Ok(
              regtestFirst
                  ? [regtestWallet, testnetWallet]
                  : [testnetWallet, regtestWallet],
            ),
          );
      final result = await GetSpSecretUsecase(
        walletRepository: wallets,
        secrets: secrets,
      ).execute(BitcoinNetwork.testnet);
      expect((result as Ok<Secret, SpFailure>).value.id, testnetSecret.id);
    });
  }
}
