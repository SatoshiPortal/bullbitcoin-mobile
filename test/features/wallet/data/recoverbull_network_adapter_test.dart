import 'dart:io';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/data/recoverbull_wallet_adapter.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart' show Secrets;
import 'package:secrets/testing.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Wallets extends Mock implements WalletRepository {}

class _Create extends Mock implements CreateDefaultWalletsUsecase {}

class _Entity extends Mock implements SettingsEntity {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a regtest recovery request never opens the keystore on mainnet',
    () async {
      final scratch = await Directory.systemTemp.createTemp(
        'recoverbull-network-',
      );
      addTearDown(() => scratch.delete(recursive: true));
      final storage = FakeSecureStoragePlatform()..install();
      final settings = _Settings();
      final entity = _Entity();
      when(() => entity.environment).thenReturn(Environment.mainnet);
      when(settings.fetch).thenAnswer((_) async => entity);
      final wallets = _Wallets();
      final create = _Create();
      final adapter = RecoverBullWalletAdapter(
        wallets,
        settings,
        Secrets(scratchDirectory: () async => scratch.path),
        create,
      );
      final result = await adapter.restoreDefaults(
        VaultContext(
          fingerprint: Fingerprint('73c5da0a'),
          network: BitcoinNetwork.regtest,
        ),
      );
      expect(result, isA<Err<VaultContext, RecoverBullFailure>>());
      expect(
        storage.reads,
        0,
        reason: 'Reject unsupported networks before custody access',
      );
      verifyZeroInteractions(wallets);
      verifyZeroInteractions(create);
    },
  );
}
