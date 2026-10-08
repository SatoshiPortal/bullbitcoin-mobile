import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart' as s;
import 'package:secrets/testing.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Wallets extends Mock implements WalletRepository {}

class _Wallet extends Mock implements Wallet {}

void main() {
  final words = [...List.filled(11, 'abandon'), 'about'];
  late FakeSecureStoragePlatform storage;
  late s.Secrets secrets;
  late _Settings settings;
  late _Wallets wallets;
  late CreateDefaultWalletsUsecase create;
  late s.Secret stored;

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secrets = s.Secrets(scratchDirectory: () async => '/tmp');
    stored =
        (await secrets.import(words: words) as Ok<s.Secret, s.SecretFailure>)
            .value;
    registerFallbackValue(stored);
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(ScriptType.bip84);
    settings = _Settings();
    wallets = _Wallets();
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => wallets.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => const Ok([]));
    create = CreateDefaultWalletsUsecase(
      secrets: secrets,
      settingsRepository: settings,
      walletRepository: wallets,
    );
  });

  for (final failedAttempt in [1, 2]) {
    test(
      'physical restore retries after wallet $failedAttempt fails',
      () async {
        storage.entries.clear();
        var attempts = 0;
        final bitcoin = _Wallet();
        final liquid = _Wallet();
        when(() => bitcoin.id).thenReturn('bitcoin');
        when(
          () => wallets.deleteWallet(walletId: 'bitcoin'),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => wallets.createWallet(
            secret: any(named: 'secret'),
            network: any(named: 'network'),
            scriptType: ScriptType.bip84,
            isDefault: true,
            birthday: null,
          ),
        ).thenAnswer((invocation) async {
          attempts++;
          final secret = invocation.namedArguments[#secret] as s.Secret;
          expect(secret.id, stored.id);
          expect(secret.info.hasPassphrase, isFalse);
          if (attempts == failedAttempt) {
            throw Exception('temporary wallet creation failure');
          }
          return invocation.namedArguments[#network] == Network.bitcoinMainnet
              ? bitcoin
              : liquid;
        });

        await expectLater(
          create.execute(mnemonicWords: words),
          throwsA(isA<CreateDefaultWalletsException>()),
        );
        final persisted = Map<String, String>.of(storage.entries);
        expect(persisted, contains('seed_${stored.id.hex}'));
        if (failedAttempt == 2) {
          verify(() => wallets.deleteWallet(walletId: 'bitcoin')).called(1);
        }

        expect(await create.execute(mnemonicWords: words), [bitcoin, liquid]);
        expect(storage.entries, persisted);
        expect(
          await secrets.import(words: words),
          isA<Err<s.Secret, s.SecretFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<s.SecretAlreadyExistsFailure>(),
          ),
        );
      },
    );
  }

  for (final failedAttempt in [1, 2]) {
    test(
      'failed generated setup removes its new secret ($failedAttempt)',
      () async {
        final before = Map<String, String>.of(storage.entries);
        var attempts = 0;
        final bitcoin = _Wallet();
        when(() => bitcoin.id).thenReturn('bitcoin');
        when(
          () => wallets.deleteWallet(walletId: 'bitcoin'),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => wallets.createWallet(
            secret: any(named: 'secret'),
            network: any(named: 'network'),
            scriptType: ScriptType.bip84,
            isDefault: true,
            birthday: any(named: 'birthday'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == failedAttempt) {
            throw Exception('temporary wallet creation failure');
          }
          return bitcoin;
        });

        await expectLater(
          create.execute(),
          throwsA(isA<CreateDefaultWalletsException>()),
        );
        expect(storage.entries, before);
      },
    );
  }

  test('preserves generated custody when wallet rollback fails', () async {
    var attempts = 0;
    late s.Secret generated;
    final bitcoin = _Wallet();
    when(() => bitcoin.id).thenReturn('bitcoin');
    when(
      () => wallets.deleteWallet(walletId: 'bitcoin'),
    ).thenAnswer((_) async => const Err(WalletStorageFailure()));
    when(
      () => wallets.createWallet(
        secret: any(named: 'secret'),
        network: any(named: 'network'),
        scriptType: ScriptType.bip84,
        isDefault: true,
        birthday: any(named: 'birthday'),
      ),
    ).thenAnswer((invocation) async {
      generated = invocation.namedArguments[#secret] as s.Secret;
      if (++attempts == 2) throw Exception('temporary wallet creation failure');
      return bitcoin;
    });

    await expectLater(
      create.execute(),
      throwsA(isA<CreateDefaultWalletsException>()),
    );
    expect(storage.entries, contains('seed_${generated.id.hex}'));
  });

  test('failure preserves a secret that predates restoration', () async {
    final persisted = Map<String, String>.of(storage.entries);
    when(
      () => wallets.createWallet(
        secret: any(named: 'secret'),
        network: any(named: 'network'),
        scriptType: ScriptType.bip84,
        isDefault: true,
        birthday: null,
      ),
    ).thenThrow(Exception('temporary wallet creation failure'));

    await expectLater(
      create.execute(mnemonicWords: words),
      throwsA(isA<CreateDefaultWalletsException>()),
    );
    verify(
      () => wallets.createWallet(
        secret: any(named: 'secret'),
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        isDefault: true,
        birthday: null,
      ),
    ).called(1);
    expect(storage.entries, persisted);
  });

  test(
    'a supplied passphrase secret is refused before wallet access',
    () async {
      final protected =
          (await secrets.import(words: words, passphrase: 'test passphrase')
                  as Ok<s.Secret, s.SecretFailure>)
              .value;
      final persisted = Map<String, String>.of(storage.entries);

      await expectLater(
        create.execute(secret: protected),
        throwsA(isA<ArgumentError>()),
      );
      verifyZeroInteractions(settings);
      verifyZeroInteractions(wallets);
      expect(storage.entries, persisted);
    },
  );
  for (final partial in [false, true]) {
    for (final useHandle in [false, true]) {
      test(
        'restoration refuses existing defaults (partial: $partial, handle: $useHandle)',
        () async {
          final bitcoin = _Wallet();
          final liquid = _Wallet();
          when(() => bitcoin.network).thenReturn(Network.bitcoinMainnet);
          when(() => liquid.network).thenReturn(Network.liquidMainnet);
          when(
            () => wallets.getWallets(
              onlyDefaults: true,
              environment: Environment.mainnet,
            ),
          ).thenAnswer((_) async => Ok([bitcoin, if (!partial) liquid]));
          final before = Map<String, String>.of(storage.entries);
          final reads = storage.reads;
          await expectLater(
            create.execute(
              secret: useHandle ? stored : null,
              mnemonicWords: useHandle ? null : words,
            ),
            throwsA(isA<CreateDefaultWalletsException>()),
          );
          expect(storage.entries, before);
          expect(storage.reads, reads);
          verifyNever(
            () => wallets.createWallet(
              secret: any(named: 'secret'),
              network: any(named: 'network'),
              scriptType: ScriptType.bip84,
              isDefault: true,
              birthday: null,
            ),
          );
        },
      );
    }
  }

  test('creation reuses complete defaults without reading custody', () async {
    final bitcoin = _Wallet();
    final liquid = _Wallet();
    when(() => bitcoin.network).thenReturn(Network.bitcoinMainnet);
    when(() => liquid.network).thenReturn(Network.liquidMainnet);
    when(
      () => wallets.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => Ok([bitcoin, liquid]));
    final reads = storage.reads;
    expect(await create.execute(), [bitcoin, liquid]);
    expect(storage.reads, reads);
  });

  test(
    'creation refuses a partial setup instead of generating another secret',
    () async {
      final bitcoin = _Wallet();
      when(() => bitcoin.network).thenReturn(Network.bitcoinMainnet);
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.mainnet,
        ),
      ).thenAnswer((_) async => Ok([bitcoin]));
      final before = Map<String, String>.of(storage.entries);
      final reads = storage.reads;
      await expectLater(
        create.execute(),
        throwsA(isA<CreateDefaultWalletsException>()),
      );
      expect(storage.entries, before);
      expect(storage.reads, reads);
    },
  );
}
