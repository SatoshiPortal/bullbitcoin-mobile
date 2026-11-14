import 'package:primitives/primitives.dart'
    show BitcoinUnit, Err, Fingerprint, Ok;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/default_wallet_failure.dart';
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
    ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([]));
    create = CreateDefaultWalletsUsecase(
      secrets: secrets,
      settingsRepository: settings,
      walletRepository: wallets,
    );
  });

  void stubCreation(List<s.Secret> received) {
    when(
      () => wallets.createWallet(
        secret: any(named: 'secret'),
        network: any(named: 'network'),
        scriptType: ScriptType.bip84,
        isDefault: true,
        birthday: null,
      ),
    ).thenAnswer((invocation) async {
      received.add(invocation.namedArguments[#secret] as s.Secret);
      return _Wallet();
    });
  }

  test('creates both default wallets from a non-English mnemonic', () async {
    final imported = await secrets.import(
      words: [...List.filled(11, 'あいこくしん'), 'あおぞら'],
      language: bip39.Language.japanese,
    );
    final secret = switch (imported) {
      Ok(:final value) => value,
      Err(:final failure) => fail('import failed: ${failure.runtimeType}'),
    };
    final received = <s.Secret>[];
    stubCreation(received);

    expect((await create.execute(secret: secret) as Ok).value, hasLength(2));
    expect(received.map((r) => r.id), [secret.id, secret.id]);
    for (final network in [Network.bitcoinMainnet, Network.liquidMainnet]) {
      verify(
        () => wallets.createWallet(
          secret: any(named: 'secret'),
          network: network,
          scriptType: ScriptType.bip84,
          isDefault: true,
          birthday: null,
        ),
      ).called(1);
    }
  });

  test('both default wallets retain the supplied passphrase secret', () async {
    final protected =
        (await secrets.import(words: words, passphrase: 'synthetic-passphrase')
                as Ok<s.Secret, s.SecretFailure>)
            .value;
    final received = <s.Secret>[];
    stubCreation(received);
    expect((await create.execute(secret: protected) as Ok).value, hasLength(2));
    expect(received.map((secret) => secret.id), [protected.id, protected.id]);
    expect(received.every((secret) => secret.info.hasPassphrase), isTrue);
  });

  test(
    'words and passphrase import and reuse the same protected secret',
    () async {
      final received = <s.Secret>[];
      stubCreation(received);
      for (var i = 0; i < 2; i++) {
        final result = await create.execute(
          mnemonicWords: words,
          passphrase: 'synthetic-passphrase',
        );
        expect((result as Ok).value, hasLength(2));
      }
      expect(received, hasLength(4));
      expect(received.every((secret) => secret.info.hasPassphrase), isTrue);
      expect(
        received.every((secret) => secret.id == received.first.id),
        isTrue,
      );
      expect(received.first.id, isNot(stored.id));
    },
  );

  test(
    'words resolving to a stored non-English duplicate use that entry',
    () async {
      // Valid in both the English and the French wordlists: one seed, so the
      // English import resolves to the French entry already stored.
      const shared = [
        'crucial', 'million', 'voyage', 'sentence', 'mobile', 'suspect', //
        'double', 'minute', 'virus', 'noble', 'junior', 'wagon',
      ];
      storage.entries.clear();
      final imported = await secrets.import(
        words: shared,
        language: bip39.Language.french,
      );
      final french = switch (imported) {
        Ok(:final value) => value,
        Err(:final failure) => fail('import failed: ${failure.runtimeType}'),
      };
      final persisted = Map<String, String>.of(storage.entries);
      final received = <s.Secret>[];
      stubCreation(received);

      expect(
        (await create.execute(mnemonicWords: shared) as Ok).value,
        hasLength(2),
      );
      expect(received.map((r) => r.id), [french.id, french.id]);
      expect(received.first.info.language, bip39.Language.french);
      expect(storage.entries, persisted);
    },
  );

  test('a passphrase without words is rejected before wallet access', () async {
    await expectLater(
      create.execute(passphrase: 'synthetic-passphrase'),
      throwsArgumentError,
    );
    await expectLater(
      create.execute(secret: stored, passphrase: 'synthetic-passphrase'),
      throwsArgumentError,
    );
    verifyZeroInteractions(settings);
    verifyZeroInteractions(wallets);
  });

  test('a seed-only secret is refused as needing a mnemonic', () async {
    // BIP32 test vector 1: seed 000102…0f, master fingerprint 3442193e.
    storage.entries['seed_3442193e'] =
        '{"bytes":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15],'
        '"runtimeType":"bytes"}';
    final seedOnly =
        (await secrets.fetch(Fingerprint('3442193e'))
                as Ok<s.Secret, s.SecretFailure>)
            .value;
    expect(seedOnly.info.language, isNull);
    expect(
      (await create.execute(secret: seedOnly) as Err).failure,
      isA<DefaultWalletMnemonicRequiredFailure>(),
    );
    verifyZeroInteractions(wallets);
    verifyZeroInteractions(settings);
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
        ).thenAnswer((_) async => const Ok<void, WalletFailure>(null));
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

        expect(
          (await create.execute(mnemonicWords: words) as Err).failure,
          isA<DefaultWalletCreationFailure>(),
        );
        final persisted = Map<String, String>.of(storage.entries);
        expect(persisted, contains('seed_${stored.id.hex}'));
        if (failedAttempt == 2) {
          verify(() => wallets.deleteWallet(walletId: 'bitcoin')).called(1);
        }

        expect((await create.execute(mnemonicWords: words) as Ok).value, [
          bitcoin,
          liquid,
        ]);
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

  test(
    'a Liquid StateError rolls back Bitcoin and allows a consistent retry',
    () async {
      final protected =
          (await secrets.import(
                    words: words,
                    passphrase: 'synthetic-passphrase',
                  )
                  as Ok<s.Secret, s.SecretFailure>)
              .value;
      final bitcoin = _Wallet();
      final liquid = _Wallet();
      when(() => bitcoin.id).thenReturn('bitcoin');
      when(() => bitcoin.network).thenReturn(Network.bitcoinMainnet);
      when(() => liquid.network).thenReturn(Network.liquidMainnet);
      final persisted = <Wallet>[];
      final received = <s.Secret>[];
      var failLiquid = true;
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.mainnet,
        ),
      ).thenAnswer(
        (_) async => Ok<List<Wallet>, WalletFailure>(List.of(persisted)),
      );
      when(
        () => wallets.createWallet(
          secret: any(named: 'secret'),
          network: any(named: 'network'),
          scriptType: ScriptType.bip84,
          isDefault: true,
          birthday: null,
        ),
      ).thenAnswer((invocation) async {
        received.add(invocation.namedArguments[#secret] as s.Secret);
        final network = invocation.namedArguments[#network] as Network;
        if (network == Network.liquidMainnet && failLiquid) {
          failLiquid = false;
          throw StateError('synthetic failure');
        }
        final wallet = network == Network.bitcoinMainnet ? bitcoin : liquid;
        persisted.add(wallet);
        return wallet;
      });
      when(() => wallets.deleteWallet(walletId: 'bitcoin')).thenAnswer((
        _,
      ) async {
        persisted.remove(bitcoin);
        return const Ok<void, WalletFailure>(null);
      });

      expect(
        (await create.execute(secret: protected) as Err).failure,
        isA<DefaultWalletCreationFailure>(),
      );
      expect(persisted, isEmpty);
      verify(() => wallets.deleteWallet(walletId: 'bitcoin')).called(1);

      expect((await create.execute(secret: protected) as Ok).value, [
        bitcoin,
        liquid,
      ]);
      expect(persisted, [bitcoin, liquid]);
      expect(received.every((secret) => secret.id == protected.id), isTrue);
    },
  );

  test(
    'a settings StateError returns a typed failure before wallet access',
    () async {
      when(() => settings.fetch()).thenThrow(StateError('synthetic failure'));
      expect(
        (await create.execute(secret: stored) as Err).failure,
        isA<DefaultWalletUnexpectedFailure>(),
      );
      verifyZeroInteractions(wallets);
    },
  );

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

    expect(
      (await create.execute(mnemonicWords: words) as Err).failure,
      isA<DefaultWalletCreationFailure>(),
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
          ).thenAnswer(
            (_) async => Ok<List<Wallet>, WalletFailure>([
              bitcoin,
              if (!partial) liquid,
            ]),
          );
          final before = Map<String, String>.of(storage.entries);
          final reads = storage.reads;
          expect(
            (await create.execute(
                      secret: useHandle ? stored : null,
                      mnemonicWords: useHandle ? null : words,
                    )
                    as Err)
                .failure,
            isA<DefaultWalletAlreadyExistsFailure>(),
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
    ).thenAnswer(
      (_) async => Ok<List<Wallet>, WalletFailure>([bitcoin, liquid]),
    );
    final reads = storage.reads;
    expect((await create.execute() as Ok).value, [bitcoin, liquid]);
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
      ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([bitcoin]));
      final before = Map<String, String>.of(storage.entries);
      final reads = storage.reads;
      expect(
        (await create.execute() as Err).failure,
        isA<DefaultWalletAlreadyExistsFailure>(),
      );
      expect(storage.entries, before);
      expect(storage.reads, reads);
    },
  );
}
