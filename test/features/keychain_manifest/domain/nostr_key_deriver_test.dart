import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart' as nostr;

void main() {
  final bytes = Uint8List.fromList(
    bip39.Mnemonic.fromSentence(
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      bip39.Language.english,
    ).seed,
  );
  final seed = Seed.bytes(
    bytes: bytes,
    masterFingerprint: hex.encode(bip32.Bip32Keys.fromSeed(bytes).fingerprint),
  );
  final time = DateTime.utc(2026, 9, 18);
  NostrKeyRecord record({
    String? publicKey,
    int identity = 1,
    String purpose = 'Personal identity',
    String description = 'Fixture',
  }) => NostrKeyRecord(
    parentFingerprint: seed.masterFingerprint,
    identity: identity,
    publicKey: publicKey ?? NostrKeyDeriver.publicKey(seed, identity),
    purpose: purpose,
    description: description,
    createdAt: time,
    updatedAt: time,
  );

  test(
    'the first user key preserves its independent public and nsec vectors',
    () {
      final key = record();
      expect(
        key.publicKey,
        'c071c9b02afd19a9d9b240ea9eed3f8ba80f89474953b752471f3d006b63a332',
      );
      expect(
        NostrKeyDeriver.reveal(seed, key),
        'nsec17s2p4ad3hpd3xs70ssq2xydj076uz6kw25m7umlf25hzmktlxydsw2t3sg',
      );
      final encoded = NostrKeyDeriver.npub(key);
      expect(nostr.Bech32Entity.decode(payload: encoded).data, key.publicKey);
      expect(
        nostr.Bech32Entity.decode(payload: encoded).prefix,
        nostr.Nip19Prefix.npub,
      );
    },
  );

  test('reveal verifies the stored public key and original seed', () {
    expect(
      () => NostrKeyDeriver.reveal(seed, record(publicKey: '0' * 64)),
      throwsFormatException,
    );
    final other = Seed.bytes(
      bytes: Uint8List.fromList(List.filled(32, 7)),
      masterFingerprint: 'aabbccdd',
    );
    expect(
      () => NostrKeyDeriver.reveal(other, record()),
      throwsFormatException,
    );
  });

  test('user keys cannot materialize reserved or out-of-bounds identities', () {
    for (final index in [0, 100, 199, 0x80000000]) {
      expect(
        () => NostrKeyDeriver.publicKey(seed, index),
        throwsFormatException,
      );
    }
    expect(
      NostrKeyDeriver.publicKey(seed, 99),
      isNot(NostrKeyDeriver.publicKey(seed, 200)),
    );
  });

  test('names and notes retain the existing form limits', () {
    expect(
      () => record(purpose: 'a' * 80, description: 'b' * 200),
      returnsNormally,
    );
    expect(() => record(purpose: 'a' * 81), throwsFormatException);
    expect(() => record(description: 'b' * 201), throwsFormatException);
    expect(() => record(purpose: 'line\nbreak'), throwsFormatException);
    expect(() => record(description: 'line\nbreak'), throwsFormatException);
  });
}
