import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/update_latest_encrypted_backup_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart' as secrets;
import 'package:secrets/testing.dart';

class _MockSettings extends Mock implements SettingsRepository {}

class _MockWallets extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

class _CountingStorage extends FakeSecureStoragePlatform {
  int writes = 0;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) {
    writes++;
    return super.write(key: key, value: value, options: options);
  }
}

T _value<T>(Result<T, secrets.SecretFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.runtimeType.toString()),
};

void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];
  const currentWords = [
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'wrong',
  ];

  late secrets.Secrets custody;
  late EncryptedVault vault;
  late String vaultKey;
  late String fingerprint;
  late _CountingStorage storage;
  late _MockSettings settings;
  late _MockWallets wallets;

  setUpAll(() async {
    FakeSecureStoragePlatform().install();
    custody = secrets.Secrets(scratchDirectory: () async => '/tmp');
    final source = _value(await custody.import(words: words));
    fingerprint = source.id.hex;
    registerFallbackValue(source);
    final backup = _value(
      await source.backup.recoverbull(
        metadata: {'masterFingerprint': '00000000'},
      ),
    );
    vault = EncryptedVault(file: backup.vault.json);
    vaultKey = backup.key.hex;
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(ScriptType.bip84);
  });

  setUp(() {
    storage = _CountingStorage()..install();
    settings = _MockSettings();
    wallets = _MockWallets();
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => wallets.updateEncryptedBackupTime(
        time: any(named: 'time'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async {});
  });

  Wallet wallet(String id, String fingerprint, Network network) {
    final wallet = _MockWallet();
    when(() => wallet.id).thenReturn(id);
    when(() => wallet.masterFingerprint).thenReturn(fingerprint);
    when(() => wallet.network).thenReturn(network);
    return wallet;
  }

  UpdateLatestEncryptedVaultTestUsecase inspection() =>
      UpdateLatestEncryptedVaultTestUsecase(
        secrets: custody,
        walletRepository: wallets,
        settingsRepository: settings,
      );

  test('creating a vault preserves the historical metadata encoding', () async {
    final secret = _value(await custody.import(words: words));
    final defaultWallet = wallet(
      'default',
      secret.id.hex,
      Network.bitcoinMainnet,
    );
    final encryptedAt = DateTime.utc(2026, 1, 2);
    final physicalAt = DateTime.utc(2026, 2, 3);
    when(() => defaultWallet.isEncryptedVaultTested).thenReturn(true);
    when(() => defaultWallet.isPhysicalBackupTested).thenReturn(false);
    when(() => defaultWallet.latestEncryptedBackup).thenReturn(encryptedAt);
    when(() => defaultWallet.latestPhysicalBackup).thenReturn(physicalAt);
    when(
      () => wallets.getWallets(onlyBitcoin: true, onlyDefaults: true),
    ).thenAnswer((_) async => Ok([defaultWallet]));
    final create = CreateEncryptedVaultUsecase(
      secrets: custody,
      walletRepository: wallets,
    );

    final result = await create.execute();

    expect(
      result,
      isA<
        Ok<({EncryptedVault vault, String vaultKey}), RecoverBullCoreFailure>
      >(),
    );
    final created =
        (result
                as Ok<
                  ({EncryptedVault vault, String vaultKey}),
                  RecoverBullCoreFailure
                >)
            .value;
    final restored = _value(
      await custody.recoverbull.restore(
        vault: secrets.EncryptedVault(json: created.vault.toFile()),
        key: secrets.VaultKey(created.vaultKey),
      ),
    );
    expect(restored.secret.id, secret.id);
    expect(restored.metadata, {
      'masterFingerprint': secret.id.hex,
      'isEncryptedVaultTested': true,
      'isPhysicalBackupTested': false,
      'latestEncryptedBackup': encryptedAt.toIso8601String(),
      'latestPhysicalBackup': physicalAt.toIso8601String(),
    });
  });

  test(
    'backup inspection derives its fingerprint without touching custody',
    () async {
      final current = _value(await custody.import(words: currentWords));
      final before = Map<String, String>.of(storage.entries);
      final reads = storage.reads;
      final writes = storage.writes;
      storage.locked = true;
      storage.writesFail = true;
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.mainnet,
        ),
      ).thenAnswer(
        (_) async => Ok([
          wallet('matching', fingerprint, Network.bitcoinMainnet),
          wallet('current', current.id.hex, Network.liquidMainnet),
        ]),
      );

      final result = await inspection().execute(
        vault: vault,
        vaultKey: vaultKey,
      );

      expect(result, isA<Ok<Null, RecoverBullCoreFailure>>());
      expect(storage.reads, reads);
      expect(storage.writes, writes);
      expect(storage.entries, before);
      final recorded = verify(
        () => wallets.updateEncryptedBackupTime(
          time: captureAny(named: 'time'),
          walletId: 'matching',
        ),
      ).captured.single;
      expect(recorded, isA<DateTime>());
      verify(
        () =>
            wallets.updateEncryptedBackupTime(time: null, walletId: 'current'),
      ).called(1);
    },
  );

  test('a wrong vault key does not update wallet backup dates', () async {
    final result = await inspection().execute(
      vault: vault,
      vaultKey: List.filled(64, '0').join(),
    );

    expect(result, isA<Err<Null, RecoverBullCoreFailure>>());
    verifyZeroInteractions(wallets);
    verifyZeroInteractions(settings);
    expect(storage.entries, isEmpty);
    expect(storage.reads, 0);
    expect(storage.writes, 0);
  });

  test(
    'restoration creates both defaults from the restored secret handle',
    () async {
      final createdSecrets = <secrets.Secret>[];
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.mainnet,
        ),
      ).thenAnswer((_) async => const Ok([]));
      when(
        () => wallets.createWallet(
          secret: any(named: 'secret'),
          network: any(named: 'network'),
          scriptType: ScriptType.bip84,
          isDefault: true,
          birthday: null,
        ),
      ).thenAnswer((invocation) async {
        final secret = invocation.namedArguments[#secret] as secrets.Secret;
        final network = invocation.namedArguments[#network] as Network;
        createdSecrets.add(secret);
        return wallet(network.name, secret.id.hex, network);
      });
      final restore = RestoreVaultUsecase(
        secrets: custody,
        walletRepository: wallets,
        createDefaultWalletsUsecase: CreateDefaultWalletsUsecase(
          secrets: custody,
          settingsRepository: settings,
          walletRepository: wallets,
        ),
      );

      final result = await restore.execute(vault: vault, vaultKey: vaultKey);

      expect(result, isA<Ok<Null, RecoverBullCoreFailure>>());
      expect(createdSecrets, hasLength(2));
      expect(
        createdSecrets.map((secret) => secret.id.hex),
        everyElement(fingerprint),
      );
      expect(
        createdSecrets.map((secret) => secret.info.hasPassphrase),
        everyElement(isFalse),
      );
      expect(_value(await createdSecrets.first.verify.mnemonic(words)), isTrue);
      verify(
        () => wallets.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: Network.bitcoinMainnet.name,
        ),
      ).called(1);
      verify(
        () => wallets.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: Network.liquidMainnet.name,
        ),
      ).called(1);
    },
  );

  test(
    'default wallets reject a passphrase handle before any mutation',
    () async {
      final secret = _value(
        await custody.import(words: words, passphrase: 'test passphrase'),
      );
      final before = Map<String, String>.of(storage.entries);
      final writes = storage.writes;
      final create = CreateDefaultWalletsUsecase(
        secrets: custody,
        settingsRepository: settings,
        walletRepository: wallets,
      );

      await expectLater(create.execute(secret: secret), throwsArgumentError);

      verifyZeroInteractions(wallets);
      verifyZeroInteractions(settings);
      expect(storage.entries, before);
      expect(storage.writes, writes);
    },
  );
}
