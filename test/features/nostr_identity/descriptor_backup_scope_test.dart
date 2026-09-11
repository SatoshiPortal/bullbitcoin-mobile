import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_nostr_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_key_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_key.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_nostr_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Resolver extends Mock implements NostrIdentityKeyResolver {}

void main() {
  final root = Bip32Keys.fromSeed(
    Uint8List.fromList(List.filled(32, 99)),
  ).toBase58();
  final key = NostrKey.derive(
    rootXprv: root,
    path: Bip85Reservations.nostrWalletBackupKey.path,
  );
  late _Resolver resolver;
  late NostrIdentityFacade facade;
  setUp(() {
    resolver = _Resolver();
    when(resolver.resolve).thenAnswer((_) async => Ok(key));
    facade = NostrIdentityFacade(
      GetNostrPublicKeyUsecase(resolver),
      SignNostrHashUsecase(resolver),
    );
  });

  test(
    'scoped authors are stable, distinct and separate from normal metadata',
    () async {
      final a = await facade.descriptorBackupPublicKey('01' * 32);
      final again = await facade.descriptorBackupPublicKey('01' * 32);
      final b = await facade.descriptorBackupPublicKey('02' * 32);
      final first = (a as Ok<String, NostrIdentityFailure>).value;
      expect((again as Ok<String, NostrIdentityFailure>).value, first);
      expect((b as Ok<String, NostrIdentityFailure>).value, isNot(first));
      expect(first, isNot(key.publicKeyHex));
      expect(
        (await facade.walletBackupPublicKey()
                as Ok<String, NostrIdentityFailure>)
            .value,
        key.publicKeyHex,
      );
    },
  );

  test(
    'scoped signatures verify and unexpected author refuses signing',
    () async {
      final lookup = '01' * 32;
      final author =
          (await facade.descriptorBackupPublicKey(lookup)
                  as Ok<String, NostrIdentityFailure>)
              .value;
      final signed = await facade.signDescriptorBackupHash(
        lookup: lookup,
        hashHex: '03' * 32,
        expectedPublicKey: author,
      );
      expect(signed, isA<Ok<String, NostrIdentityFailure>>());
      expect(
        ECPublic.fromHex('02$author').verifyBip340Signature(
          digest: hex.decode('03' * 32),
          signature: hex.decode(
            (signed as Ok<String, NostrIdentityFailure>).value,
          ),
          tweak: false,
        ),
        isTrue,
      );
      expect(
        await facade.signDescriptorBackupHash(
          lookup: lookup,
          hashHex: '03' * 32,
          expectedPublicKey: key.publicKeyHex,
        ),
        isA<Err<String, NostrIdentityFailure>>(),
      );
      final changed = NostrKey.derive(
        rootXprv: Bip32Keys.fromSeed(Uint8List(32)).toBase58(),
        path: Bip85Reservations.nostrWalletBackupKey.path,
      );
      when(resolver.resolve).thenAnswer((_) async => Ok(changed));
      expect(
        await facade.signDescriptorBackupHash(
          lookup: lookup,
          hashHex: '03' * 32,
          expectedPublicKey: author,
        ),
        isA<Err<String, NostrIdentityFailure>>(),
      );
    },
  );

  test('malformed lookup/hash never resolves private storage', () async {
    expect(
      await facade.descriptorBackupPublicKey('bad'),
      isA<Err<String, NostrIdentityFailure>>(),
    );
    expect(
      await facade.signDescriptorBackupHash(
        lookup: 'bad',
        hashHex: '03' * 32,
        expectedPublicKey: key.publicKeyHex,
      ),
      isA<Err<String, NostrIdentityFailure>>(),
    );
    expect(
      await facade.signDescriptorBackupHash(
        lookup: '01' * 32,
        hashHex: 'bad',
        expectedPublicKey: key.publicKeyHex,
      ),
      isA<Err<String, NostrIdentityFailure>>(),
    );
    verifyNever(resolver.resolve);
  });

  test('unavailable key storage is preserved as failure', () async {
    when(
      resolver.resolve,
    ).thenAnswer((_) async => const Err(NostrIdentityUnavailableFailure()));
    expect(
      await facade.descriptorBackupPublicKey('01' * 32),
      isA<Err<String, NostrIdentityFailure>>(),
    );
  });
}
