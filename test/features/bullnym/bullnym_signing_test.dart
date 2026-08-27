import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/bullnym_locator.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_repository_impl.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/repositories/bullnym_repository.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/bullnym_usecases.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  const npub =
      'c071c9ae5ef050c69bb38f8ff03c35f1a89b50ef9ad951e5b4f2d1fb9e8e0e4d';
  const signature =
      '11a90a7242720482d42a2853d7b128eb9de7346934f1cfbdb6ce8368b5e9a262'
      '440a6f09a256247d78d4d501c291aa10349aa23609c72a9ab179ba29a59411e0';

  test('builds the frozen Bullpay NUL-separated byte layout', () {
    final bytes = buildBullnymMessage(
      action: 'register',
      npubHex: npub,
      nym: 'alice',
      fields: const ['descriptor', 'verification'],
      timestamp: 1710000000,
    );

    expect(
      utf8.decode(bytes!),
      'bullpay-la-v2\u0000register\u0000$npub\u0000alice\u0000'
      'descriptor\u0000verification\u00001710000000',
    );
  });

  test('keeps endpoint field order outside the shared signer', () {
    final first = buildBullnymMessage(
      action: 'invoice-create',
      npubHex: npub,
      nym: '',
      fields: const ['1', '2'],
      timestamp: 3,
    );
    final reversed = buildBullnymMessage(
      action: 'invoice-create',
      npubHex: npub,
      nym: '',
      fields: const ['2', '1'],
      timestamp: 3,
    );

    expect(first, isNot(reversed));
    expect(
      buildBullnymMessage(
        action: 'x',
        npubHex: npub,
        nym: '',
        fields: const ['bad\u0000field'],
        timestamp: 3,
      ),
      isNull,
    );
  });

  test('builds backup bytes and deterministic ETags', () {
    final message = buildBullnymBackupMessage(
      action: 'backup-store',
      stream: BullnymBackupStream.walletBackup,
      npubHex: npub,
      generation: 2,
      expectedEtag: '22' * 32,
      ciphertextSha256: '33' * 32,
      ciphertextBytes: 64,
      timestamp: 1710000000,
    );

    expect(
      utf8.decode(message!),
      'bullbitcoin-wallet-backup-v1\u0000backup-store\u0000wallet_backup\u0000'
      '$npub\u00002\u0000${'22' * 32}\u0000${'33' * 32}\u000064\u00001710000000',
    );
    expect(
      computeBullnymBackupEtag(
        stream: BullnymBackupStream.walletBackup,
        npubHex: npub,
        generation: 2,
        ciphertextSha256: '33' * 32,
      ),
      sha256
          .convert(
            utf8.encode(
              'bullbitcoin-wallet-backup-etag-v1\u0000wallet_backup\u0000'
              '$npub\u00002\u0000${'33' * 32}',
            ),
          )
          .toString(),
    );
  });

  test(
    'adapts the purpose-scoped identity without exposing a key handle',
    () async {
      final identity = _MockNostrIdentityFacade();
      late String signedDigest;
      when(identity.bullnymAuthPublicKey).thenAnswer(
        (_) async => const Ok(NostrPublicKey(hex: npub, npub: 'npub1test')),
      );
      when(() => identity.signBullnymAuthHash(any())).thenAnswer((
        invocation,
      ) async {
        signedDigest = invocation.positionalArguments.single as String;
        return const Ok(signature);
      });
      final authenticator = BullnymAuthenticator(
        identity,
        nowSecs: () => 1710000000,
      );

      final result = await authenticator.sign(
        action: 'register',
        nym: '',
        fields: const [],
      );

      final expectedBytes = buildBullnymMessage(
        action: 'register',
        npubHex: npub,
        nym: '',
        fields: const [],
        timestamp: 1710000000,
      );
      expect(signedDigest, sha256.convert(expectedBytes!).toString());
      expect(
        result,
        isA<Ok<BullnymAuthentication, BullnymFailure>>().having(
          (value) => value.value.signatureHex,
          'signature',
          signature,
        ),
      );
      verify(identity.bullnymAuthPublicKey).called(1);
      verify(() => identity.signBullnymAuthHash(signedDigest)).called(1);
    },
  );

  test(
    'maps identity failures without retaining secret-adjacent details',
    () async {
      final identity = _MockNostrIdentityFacade();
      when(identity.bullnymAuthPublicKey).thenAnswer(
        (_) async => const Err(NostrIdentitySeedUnavailableFailure()),
      );

      final result = await BullnymAuthenticator(
        identity,
      ).sign(action: 'register', nym: '', fields: const []);

      expect(result, isA<Err<BullnymAuthentication, BullnymFailure>>());
      expect(
        (result as Err<BullnymAuthentication, BullnymFailure>).failure,
        isA<BullnymAuthenticationFailure>(),
      );
      verifyNever(() => identity.signBullnymAuthHash(any()));
    },
  );

  test('registers only the facade in the application container', () {
    final getIt = GetIt.asNewInstance()
      ..registerSingleton<NostrIdentityFacade>(_MockNostrIdentityFacade());
    addTearDown(getIt.reset);

    BullnymLocator.setup(getIt);

    expect(getIt.isRegistered<BullnymFacade>(), isTrue);
    expect(getIt.isRegistered<BullnymAuthenticator>(), isFalse);
    expect(getIt.isRegistered<BullnymRepositoryImpl>(), isFalse);
  });

  test('registration lookup resolves the public key without signing', () async {
    final identity = _MockNostrIdentityFacade();
    final repository = _MockBullnymRepository();
    when(identity.bullnymAuthPublicKey).thenAnswer(
      (_) async => const Ok(NostrPublicKey(hex: npub, npub: 'npub1test')),
    );
    when(() => repository.lookupRegistration(npub)).thenAnswer(
      (_) async => const Ok(BullnymLookupResult(nym: 'alice', active: true)),
    );

    final result = await LookupBullnymRegistrationUsecase(
      repository,
      BullnymAuthenticator(identity),
    ).execute();

    expect(result, isA<Ok<BullnymLookupResult, BullnymFailure>>());
    verify(identity.bullnymAuthPublicKey).called(1);
    verify(() => repository.lookupRegistration(npub)).called(1);
    verifyNever(() => identity.signBullnymAuthHash(any()));
  });
}

final class _MockNostrIdentityFacade extends Mock
    implements NostrIdentityFacade {}

final class _MockBullnymRepository extends Mock implements BullnymRepository {}
