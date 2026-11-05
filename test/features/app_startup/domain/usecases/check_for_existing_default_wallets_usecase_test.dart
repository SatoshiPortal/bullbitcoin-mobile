import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _WalletRepository extends Mock implements WalletRepository {}

class _SettingsRepository extends Mock implements SettingsRepository {}

class _Settings extends Mock implements SettingsEntity {}

void main() {
  late _WalletRepository wallets;
  late FakeSecureStoragePlatform storage;
  late CheckForExistingDefaultWalletsUsecase usecase;
  late List<String> events;

  setUp(() {
    wallets = _WalletRepository();
    // Custody is observed at the plugin seam: `Secrets` takes no injected
    // store, so "no interaction" means no keystore read and no write.
    storage = FakeSecureStoragePlatform()..install();
    events = [];
    final settings = _SettingsRepository();
    final configuration = _Settings();
    when(() => configuration.environment).thenReturn(Environment.mainnet);
    when(settings.fetch).thenAnswer((_) async => configuration);
    when(wallets.deleteLwkDb).thenAnswer((_) async => events.add('delete'));
    usecase = CheckForExistingDefaultWalletsUsecase(
      settingsRepository: settings,
      walletRepository: wallets,
      secrets: Secrets(scratchDirectory: () async => '/tmp'),
    );
  });

  void expectNoCustodyAccess() {
    expect(storage.reads, 0);
    expect(storage.entries, isEmpty);
  }

  void reads(List<Result<List<Wallet>, WalletFailure>> results) {
    var index = 0;
    when(
      () => wallets.getWallets(
        onlyDefaults: true,
        isMainnet: Environment.mainnet.isMainnet,
      ),
    ).thenAnswer((_) async {
      events.add('read');
      return results[index++];
    });
  }

  test('a Liquid status conflict deletes its cache before retrying', () async {
    reads([const Err(WalletLwkStatusConflictFailure()), const Ok(<Wallet>[])]);

    final result = await usecase.execute();

    expect(result, isA<Ok<bool, AppStartupFailure>>());
    expect((result as Ok<bool, AppStartupFailure>).value, isFalse);
    expect(events, ['read', 'delete', 'read']);
    verify(wallets.deleteLwkDb).called(1);
    expectNoCustodyAccess();
  });

  test('a repeated Liquid conflict fails after exactly one retry', () async {
    reads([
      const Err(WalletLwkStatusConflictFailure()),
      const Err(WalletLwkStatusConflictFailure()),
    ]);

    final result = await usecase.execute();

    expect(result, isA<Err<bool, AppStartupFailure>>());
    expect(
      (result as Err<bool, AppStartupFailure>).failure,
      isA<AppStartupWalletCheckFailure>(),
    );
    expect(events, ['read', 'delete', 'read']);
    verify(wallets.deleteLwkDb).called(1);
    expectNoCustodyAccess();
  });

  test(
    'an unrelated storage failure does not delete the Liquid cache',
    () async {
      reads([const Err(WalletStorageFailure())]);

      final result = await usecase.execute();

      expect(result, isA<Err<bool, AppStartupFailure>>());
      expect(events, ['read']);
      verifyNever(wallets.deleteLwkDb);
      expectNoCustodyAccess();
    },
  );
}
