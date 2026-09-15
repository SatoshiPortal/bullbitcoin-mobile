import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_backup_identity_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_backup_identity_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/nostr_identity_locator.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr/nostr.dart' as nostr;

class _MockSettings extends Mock implements GetSettingsUsecase {}

class _MockDefaultSeed extends Mock implements GetDefaultSeedUsecase {}

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _hash =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _backupWords =
    'industry unknown simple danger local example wreck cream cat correct soldier buzz';
const _nostrPublicKey =
    'e3fcc9856099dc37eee21f66471290cbe48dfef143a32d4f81a86e3f17872fac';

void main() {
  late Seed seed;
  late _MockSettings settings;
  late _MockDefaultSeed defaultSeed;
  late NostrIdentityFacade facade;

  setUpAll(() {
    final bytes = Uint8List.fromList(
      bip39.Mnemonic.fromSentence(_mnemonic, bip39.Language.english).seed,
    );
    seed = Seed.bytes(
      bytes: bytes,
      masterFingerprint: hex.encode(
        bip32.Bip32Keys.fromSeed(bytes).fingerprint,
      ),
    );
  });

  setUp(() {
    settings = _MockSettings();
    defaultSeed = _MockDefaultSeed();
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CRC',
      ),
    );
    when(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).thenAnswer((_) async => Ok<Seed, SeedFailure>(seed));
    facade = _facade(settings, defaultSeed);
  });

  test('serves the two identities the backup words derive', () async {
    final artifactAuthor = await facade.walletBackupPublicKey();
    final serverAccount = await facade.walletBackupServerPublicKey();

    final author = _ok(artifactAuthor);
    final account = _ok(serverAccount);
    expect(author, _nostrPublicKey);
    expect(account, isNot(author));
    expect(
      nostr.Bech32Entity.encode(prefix: nostr.Nip19Prefix.npub, data: author),
      'npub1u07vnptqn8wr0mhzranywy5se0jgmlh3gw3j6nup4phr79u897kqf7t75t',
    );
  });

  test('reveals the twelve words the default seed owns', () async {
    expect(_ok(await facade.revealBackupWords()), _backupWords);
    expect(
      _ok(await facade.revealBackupWords()).split(' '),
      hasLength(12),
      reason: 'the frozen twelve-word form',
    );
  });

  test('signs under each identity and nothing else', () async {
    final artifact = _ok(await facade.signWalletBackupHash(_hash));
    final server = _ok(await facade.signWalletBackupServerHash(_hash));

    expect(artifact, isNot(server));
    for (final signed in [
      (_ok(await facade.walletBackupPublicKey()), artifact),
      (_ok(await facade.walletBackupServerPublicKey()), server),
    ]) {
      expect(
        ECPublic.fromHex('02${signed.$1}').verifyBip340Signature(
          digest: hex.decode(_hash),
          signature: hex.decode(signed.$2),
          tweak: false,
        ),
        isTrue,
      );
    }
    expect(
      ECPublic.fromHex(
        '02${_ok(await facade.walletBackupPublicKey())}',
      ).verifyBip340Signature(
        digest: hex.decode(_hash),
        signature: hex.decode(server),
        tweak: false,
      ),
      isFalse,
    );
  });

  test('pins reserved payment identity vectors without runtime APIs', () {
    final rootXprv = Bip32Derivation.getCanonicalRootXprvFromSeed(seed.bytes);

    expect(
      _reservedNostrKey(rootXprv, Bip85Reservations.nostrBullnymServerAuthKey),
      '1d11451fdea6a9e291265e6ebf0eba04145f4bd2a15e7cea11978430f1011cf3',
    );
    expect(
      _reservedNostrKey(
        rootXprv,
        Bip85Reservations.nostrNip05PublicNymVerificationKey,
      ),
      'f1b86d6ed23fbdebf687a2d4f39c7e35d6cee5a38f8959c27a4454ce1b494b1b',
    );
  });

  test('the retired backup paths stay claimed and unused', () {
    for (final retired in [
      Bip85Reservations.retiredWalletBackupNostrKeyPath,
      Bip85Reservations.retiredWalletBackupEncryptionKeyPath,
    ]) {
      expect(Bip85Reservations.reservedPaths, contains(retired));
      expect(Bip85Reservations.reservationByExactPath(retired), isNull);
    }
    // The artifact identity path is spelled like the retired parent-seed path,
    // but it is derived on the words' root: same string, different key.
    expect(
      _nostrKeyAtPath(
        Bip32Derivation.getCanonicalRootXprvFromSeed(seed.bytes),
        Bip85Reservations.retiredWalletBackupNostrKeyPath,
      ),
      isNot(_nostrPublicKey),
    );
  });

  test('rejects a malformed digest before loading wallet secrets', () async {
    for (final digest in ['abcd', '', 'zz' * 32]) {
      expect(
        await facade.signWalletBackupHash(digest),
        isA<Err<String, NostrIdentityFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<NostrIdentityInvalidHashFailure>(),
        ),
      );
      expect(
        await facade.signWalletBackupServerHash(digest),
        isA<Err<String, NostrIdentityFailure>>(),
      );
    }
    verifyNever(() => settings.execute());
    verifyNever(
      () => defaultSeed.execute(environment: any(named: 'environment')),
    );
  });

  final failureCases = <({String name, SeedFailure source})>[
    (
      name: 'reports a missing default wallet',
      source: const DefaultSeedNotFoundFailure(),
    ),
    (
      name: 'reports ambiguous default wallets',
      source: const DefaultSeedAmbiguousFailure(),
    ),
    (
      name: 'reports wallet lookup failure',
      source: const DefaultSeedWalletLookupFailure(),
    ),
    (
      name: 'reports an unavailable seed',
      source: const DefaultSeedUnavailableFailure(),
    ),
    (
      name: 'reports a default-seed fingerprint mismatch',
      source: const DefaultSeedFingerprintMismatchFailure(),
    ),
  ];
  for (final failureCase in failureCases) {
    test(failureCase.name, () async {
      when(
        () => defaultSeed.execute(environment: Environment.mainnet),
      ).thenAnswer((_) async => Err<Seed, SeedFailure>(failureCase.source));

      for (final call in [
        facade.walletBackupPublicKey,
        facade.walletBackupServerPublicKey,
        facade.revealBackupWords,
      ]) {
        expect(
          await call(),
          isA<Err<String, NostrIdentityFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<NostrIdentityUnavailableFailure>(),
          ),
        );
      }
    });
  }

  test('maps settings lookup exceptions without exposing details', () async {
    when(() => settings.execute()).thenThrow(Exception('storage detail'));

    expect(
      await facade.walletBackupPublicKey(),
      isA<Err<String, NostrIdentityFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<NostrIdentityUnavailableFailure>(),
      ),
    );
  });

  test('uses the active environment when resolving the default seed', () async {
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CRC',
      ),
    );
    when(
      () => defaultSeed.execute(environment: Environment.testnet),
    ).thenAnswer((_) async => Ok<Seed, SeedFailure>(seed));

    expect(
      await facade.walletBackupPublicKey(),
      isA<Ok<String, NostrIdentityFailure>>(),
    );
    verify(
      () => defaultSeed.execute(environment: Environment.testnet),
    ).called(1);
  });

  test('registers only the facade in the application container', () {
    final getIt = GetIt.asNewInstance()
      ..registerSingleton<GetSettingsUsecase>(settings)
      ..registerSingleton<GetDefaultSeedUsecase>(defaultSeed);
    addTearDown(getIt.reset);

    NostrIdentityLocator.setup(getIt);

    expect(getIt.isRegistered<NostrIdentityFacade>(), isTrue);
    expect(getIt.isRegistered<BackupCredentialResolver>(), isFalse);
    expect(getIt.isRegistered<GetBackupIdentityPublicKeyUsecase>(), isFalse);
    expect(getIt.isRegistered<SignBackupIdentityHashUsecase>(), isFalse);
  });

  test('does not catch programmer errors', () async {
    when(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).thenThrow(StateError('programmer bug'));

    expect(facade.walletBackupPublicKey, throwsA(isA<StateError>()));
  });
}

String _ok(Result<String, NostrIdentityFailure> result) {
  expect(result, isA<Ok<String, NostrIdentityFailure>>());
  return (result as Ok<String, NostrIdentityFailure>).value;
}

String _reservedNostrKey(String rootXprv, Bip85Reservation reservation) =>
    _nostrKeyAtPath(rootXprv, reservation.path);

String _nostrKeyAtPath(String rootXprv, String path) => hex.encode(
  ECPrivate.fromHex(
    bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: rootXprv,
      path: bip85.Bip85HardenedPath(path),
    ).substring(0, 64),
  ).getPublic().toXOnly(),
);

NostrIdentityFacade _facade(
  GetSettingsUsecase settings,
  GetDefaultSeedUsecase defaultSeed,
) {
  final resolver = BackupCredentialResolver(settings, defaultSeed);
  return NostrIdentityFacade(
    GetBackupIdentityPublicKeyUsecase(resolver),
    SignBackupIdentityHashUsecase(resolver),
    resolver,
  );
}
