import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_nostr_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_key_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_nostr_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/nostr_identity_locator.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettings extends Mock implements GetSettingsUsecase {}

class _MockDefaultSeed extends Mock implements GetDefaultSeedUsecase {}

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _hash =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

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

  test('derives the three identities from their frozen paths', () async {
    final backup = await facade.walletBackupPublicKey();
    final auth = await facade.bullnymAuthPublicKey();
    final verification = await facade.nip05VerificationPublicKey();

    expect(
      backup,
      isA<Ok<NostrPublicKey, NostrIdentityFailure>>().having(
        (result) => result.value.hex,
        'wallet backup public key',
        '4fb85384f3a52baadbadc3f9bcb7fd59691e323293160b58959dadd6195c7981',
      ),
    );
    expect(
      auth,
      isA<Ok<NostrPublicKey, NostrIdentityFailure>>().having(
        (result) => result.value.hex,
        'Bullnym authentication public key',
        '1d11451fdea6a9e291265e6ebf0eba04145f4bd2a15e7cea11978430f1011cf3',
      ),
    );
    expect(
      verification,
      isA<Ok<NostrPublicKey, NostrIdentityFailure>>().having(
        (result) => result.value.hex,
        'NIP-05 verification public key',
        'f1b86d6ed23fbdebf687a2d4f39c7e35d6cee5a38f8959c27a4454ce1b494b1b',
      ),
    );
    expect(
      (backup as Ok<NostrPublicKey, NostrIdentityFailure>).value.npub,
      'npub1f7u98p8n55464kadc0umedlat953uv3jjvtqkky4nkkavx2u0xqsvsgq2t',
    );
  });

  test('signs the frozen digest without exposing a private key', () async {
    final publicKey = await facade.walletBackupPublicKey();
    final signature = await facade.signWalletBackupHash(_hash);

    final publicKeyHex =
        (publicKey as Ok<NostrPublicKey, NostrIdentityFailure>).value.hex;
    final signatureHex = (signature as Ok<String, NostrIdentityFailure>).value;
    expect(
      signatureHex,
      'da19ff41d148b058411c1df044f8595f0e6f05261eec000e8446461d185d739b'
      'f74262ec740930f36fad2ca58e8c0026978d27a0035832403d8bfa37e5c712fd',
    );
    expect(
      ECPublic.fromHex('02$publicKeyHex').verifyBip340Signature(
        digest: hex.decode(_hash),
        signature: hex.decode(signatureHex),
        tweak: false,
      ),
      isTrue,
    );
  });

  test('rejects a malformed digest before loading wallet secrets', () async {
    expect(
      await facade.signBullnymAuthHash('abcd'),
      isA<Err<String, NostrIdentityFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<NostrIdentityInvalidHashFailure>(),
      ),
    );
    verifyNever(() => settings.execute());
    verifyNever(
      () => defaultSeed.execute(environment: any(named: 'environment')),
    );
  });

  final failureCases = <({String name, SeedFailure source, Matcher expected})>[
    (
      name: 'reports a missing default wallet',
      source: const DefaultSeedNotFoundFailure(),
      expected: isA<NostrIdentityNoDefaultWalletFailure>(),
    ),
    (
      name: 'reports ambiguous default wallets',
      source: const DefaultSeedAmbiguousFailure(),
      expected: isA<NostrIdentityAmbiguousDefaultWalletFailure>(),
    ),
    (
      name: 'reports wallet lookup failure',
      source: const DefaultSeedWalletLookupFailure(),
      expected: isA<NostrIdentityWalletLookupFailure>(),
    ),
    (
      name: 'reports an unavailable seed',
      source: const DefaultSeedUnavailableFailure(),
      expected: isA<NostrIdentitySeedUnavailableFailure>(),
    ),
    (
      name: 'reports a default-seed fingerprint mismatch',
      source: const DefaultSeedFingerprintMismatchFailure(),
      expected: isA<NostrIdentityFingerprintMismatchFailure>(),
    ),
  ];
  for (final failureCase in failureCases) {
    test(failureCase.name, () async {
      when(
        () => defaultSeed.execute(environment: Environment.mainnet),
      ).thenAnswer((_) async => Err<Seed, SeedFailure>(failureCase.source));

      expect(
        await facade.walletBackupPublicKey(),
        isA<Err<NostrPublicKey, NostrIdentityFailure>>().having(
          (result) => result.failure,
          'failure',
          failureCase.expected,
        ),
      );
    });
  }

  test('maps settings lookup exceptions without exposing details', () async {
    when(() => settings.execute()).thenThrow(Exception('storage detail'));

    expect(
      await facade.bullnymAuthPublicKey(),
      isA<Err<NostrPublicKey, NostrIdentityFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<NostrIdentityWalletLookupFailure>(),
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
      isA<Ok<NostrPublicKey, NostrIdentityFailure>>(),
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
    expect(getIt.isRegistered<NostrIdentityKeyResolver>(), isFalse);
    expect(getIt.isRegistered<GetNostrPublicKeyUsecase>(), isFalse);
    expect(getIt.isRegistered<SignNostrHashUsecase>(), isFalse);
  });

  test('does not catch programmer errors', () async {
    when(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).thenThrow(StateError('programmer bug'));

    expect(facade.walletBackupPublicKey, throwsA(isA<StateError>()));
  });
}

NostrIdentityFacade _facade(
  GetSettingsUsecase settings,
  GetDefaultSeedUsecase defaultSeed,
) {
  final resolver = NostrIdentityKeyResolver(settings, defaultSeed);
  return NostrIdentityFacade(
    GetNostrPublicKeyUsecase(resolver),
    SignNostrHashUsecase(resolver),
  );
}
